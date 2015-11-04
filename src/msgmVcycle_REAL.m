function x = msgmVcycle_REAL(G, x, gP)

%
% Vcycle(D,E,W,L,gP)    -   A multiscale scheme for finding minimum energy
%                           assignments of pairwise MRFs
%
% Assume N variables, M edges, and K labels
%
% INPUT:
%
%   U   -   unary term, NxK matrix.
%           U(i,li) is the cost of assigning label 'li' to vertex 'i'
%
%
%   E   -   adjacency matrix, NxN matrix.
%           Let i,j denote two vertices; if the edge (i,j) exists, then
%           E(i,j) is an index pointing to the explicit representation
%           of their pairwise term in matrix 'P'. E(i,j) is zero otherwise.
%
%   P   -   explicit representation of all pairwise terms, KxKxM matrix.
%           If the edge connecting vertices (i,j) is indexed by 'k', then
%           P(li,lj,k) is the cost of assigning label 'li' to 'i' and
%           'lj' to 'j'. Note that in general P(y,z,:)!=P(z,y,:)
%
%   L   -   initial labeling of the vertices, Nx1 vector.
%           For an unlabeled graph, L should be the empty matrix [].
%
%   gP  -   set of parameters. See setParams().
%
%   fineGraph - (true/false) was the original fine graph passed as input to
%               msmrf(), or is it a coarsened version of it?
%               This information is used to save on computational resources
%               by not applying 'ReparmGraph()' on the finest graph more
%               than once.
%
%
% OUTPUT:
%
%   L   -   a labeling assignment to the vertices, Nx1 vector.
%


%
% reparameterize the unary and pairwise
% terms of the graphical model U,E,P
[G.u, G.p] = ReparamGraph(G.u, G.adj, G.p, gP);


%
% relax the graph
% TODO: it may work better if the graph is first processed (read:
% reparamterized)
x = RelaxGraph(G.u, G.adj, G.p, x, gP);


%
% score the edges, a preprocessing step
% for CompCoarseGraph()
%vEdgeList = ScoreEdges(GU,E,P,prior,x,gP);      

%
% compute coarse graphical model,
% according to 'vEdgeList'
[Gc, xc, mapFineToCoarse, mapInterpolation] = msgmCoarsening_REAL(G, x);
if (any(xc))
    EnergyAssert(G.u, G.adj, G.p, x, Gc.u, Gc.adj, Gc.p, xc);
    EnergyAssert(Gc.u, Gc.adj, Gc.p, xc, G.u, G.adj, G.p, x);
end
    
%
% check stopping condition
% TODO: check if crsRatioThrs is necessary, if not - can bring to first
% step if V-cycle
% TODO: set size(Uc,1) <= 2
if (size(Gc.u,1)/size(G.u,1) >= gP.crsRatioThrs) || ...
        (size(Gc.u,1) <= 500)
    % coarsening ratio is above threshold, stop the recursion
   
%     x = Solve(Gc.u, Gc.adj, Gc.p, xc, [], ...
%         G.u, G.adj, G.p, x, [],...
%         vCoarse, plongTab, gP);

    if (isempty(xc))
        
        % "winner takes all", initialize according to unary term
        % TODO: decide what to do here, relax should work...
        [~, xc] = min(Gc.u, [], 2);
        
        % solve
        if (numel(xc) == 2)
            % exhaustive
            
            K = size(Gc.u,2);     % number of labels
            pairwise = Gc.p;
            ii = Gc.adj(1);         % left vertex of pairwise
            jj = Gc.adj(2);         % right vertex of pairwise

            % find optimal assignment
            minEng = Inf;
            xc = zeros(2,1);
            for i = 1 : K
                for j = 1 : K    

                    e = Gc.u(ii,i) + Gc.u(jj,j) + pairwise(i,j);
                    if (e <= minEng)
                        minEng = e;
                        xc([ii,jj]) = [i;j];
                    end
                end
            end
        else
            nRelaxOrig = gP.numRelax;
            gP.numRelax = 1;
            xc = RelaxGraph(Gc.u, Gc.adj, Gc.p, xc, gP);
            gP.numRelax = nRelaxOrig;
        end
    end

    xc = RelaxGraph(Gc.u, Gc.adj, Gc.p, xc, gP);
    x = msgmInterpolate(xc, mapFineToCoarse, mapInterpolation);
    EnergyAssert(G.u, G.adj, G.p, x, Gc.u, Gc.adj, Gc.p, xc);
    EnergyAssert(Gc.u, Gc.adj, Gc.p, xc, G.u, G.adj, G.p, x);
    x = RelaxGraph(G.u, G.adj, G.p, x, gP);

    return
end


%
% recursive call
xc = msgmVcycle_REAL(Gc, xc, gP);


%
% interpolate solution
% TODO: shove the compatible relaxations into msgmInterpolate
if not(gP.bPlongCR)

    
    x = msgmInterpolate(xc, mapFineToCoarse, mapInterpolation);
else

    [Ucr, Ecr, Pcr, Lcr, vCR2Fine, x] = MakeCRgraph(G.u, G.adj, G.p, xc, vCoarse, plongTab);
    L_ = ProlongP(x,Lcr,vCR2Fine);
    gP_ = gP;
    gP_.numRelax = 5;
    Lcr = RelaxGraph(Ucr,Ecr,Pcr,Lcr,gP_);
    x = ProlongP(x,Lcr,vCR2Fine);
    EnergyAssert(U,E,P,x,U,E,P,L_);
end



%
% assertion - remove later
% TODO: REMOVE
EnergyAssert(G.u, G.adj, G.p, x, Gc.u, Gc.adj, Gc.p,xc);
    

%
% relax the graph
x = RelaxGraph(G.u, G.adj, G.p, x, gP);


end