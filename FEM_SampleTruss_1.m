% FEM Sample Truss

% Clear Command Window and Workspace
clear all, clc;


% Constants for the beam (A is area, E is elastic modulus, L is beam lengths, theta)
A = 0.0015875*0.017; 
E = 10391670000;
P = 1;

%CHANGE THESE VALUES
%length array for every member beam
%L = [6; 6*sqrt(3); 12];
L = [5;3;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34);6;sqrt(34)]
%theta array corresponds to lengths, note it is from node 1 to node 2
%theta = [60; 150; 0]; 
theata = [90;0;atand(5/3);0;atand(-5/3);0;atand(5/3);0;atand(-5/3);0;atand(5/3);0;atand(-5/3);0;atand(5/3);0;atand(-5/3);0;atand(5/3);0;atand(-5/3)]
%node array corresponds to beam, angles are from node #1 to node #2
%nodes = [1 3; 2 3; 1 2]
nodes = [1 2; 1 3; 2 3; 2 4; 3 4; 3 5; 4 5; 4 6;5 6; 5 7; 6 7; 6 8; 7 8; 7 9; 8 9; 8 10; 9 10; 9 11; 10 11; 10 12; 11 12]
%number of total nodes in the system
%numNodes = 3
numNodes = 12
%index where external load P is exerted, note note this index is determined
%by using node*2-1 if the force is in the x direction or by using node*2
%if the force is in the direction
%forceIndex = 5
forceIndex = 24 
%these indexes are using the nodal indexes in terms of directions, for the
%x direction index is equal to node*2 - 1, for y direction index is equal
%to node*2
%zeroDisplacementIndices = [1 2 4]
zeroDisplacementIndices = [1 2 3]
%CHANGE THESE VALUES

calculateBridgeValues(numNodes, P, E, A, L, theata, nodes, forceIndex, zeroDisplacementIndices)

function [] = calculateBridgeValues(numNodes, load, eMod, area, lengths, angles, nodes, pIndex, ignoredIndices) 
    %Varibles for the stress
     t = 0.0015875
     d = 0.0047625
     b = 0.0085
     w = 0.017
     tHigh = 0
     cHigh = 0
     tRupture = 0
     cRupture = 0
     yeild = 65141501.9
     fHgih = 0
     bearing = 0
     tearout = 0
     buckling = 0
     l = 0.03 %Lowest length of the link under compression
     r = 0
    
    numDofs = numNodes*2
    K = zeros(numDofs)
    k = eMod.*area./lengths;
    mainLoopCount = length(lengths)
    for x = 1:mainLoopCount
        K = generateBeamStiffnessMatrix(nodes(x, 1), nodes(x,2), angles(x), numDofs, K, k(x))
    end
    
    %TESTED UP TO THIS POINT
    externalForces = []
    indexCounter = 0
    for x = 1:numDofs
        if ismember(x, ignoredIndices)
        elseif x == pIndex
            externalForces(end+1) = load
        else
            externalForces(end+1) = 0
        end
    end
    externalForces = externalForces'
    
    kArrayPreSolve = K
    for x = numDofs:-1:1
        if ismember(x, ignoredIndices)
            kArrayPreSolve(x, :) = []
        end
    end
    
    for x = numDofs:-1:1
        if ismember(x, ignoredIndices)
            kArrayPreSolve(:, x) = []
        end
    end
    
    u = kArrayPreSolve \ externalForces
    U = []
    uIndex = 1
    for x = 1:numDofs
        if ismember(x, ignoredIndices)
            U(end+1)= 0
        else
            U(end+1)= u(uIndex)
            uIndex = uIndex + 1
        end   
    end
    
    memberForces = []    
    for x = 1:mainLoopCount
        f = determineForce(nodes(x, 1), nodes(x,2), angles(x), k(x), U)
        memberForces = [memberForces; f]
    end 
    
    %calculate resultant forces at each node
    nodeResultantX  = zeros(numNodes, 1)
    nodeResultantY = zeros(numNodes, 1)
    for x = 1:length(nodes)
        node1 = nodes(x, 1)
        node2 = nodes(x, 2)
        xComponent = abs(memberForces(x)*cosd(angles(x)))
        yComponent = abs(memberForces(x)*sind(angles(x)))
        nodeResultantX(node1, 1) = nodeResultantX(node1, 1) + xComponent
        nodeResultantX(node2, 1) = nodeResultantX(node2, 1) + xComponent
        nodeResultantY(node1, 1) = nodeResultantY(node1, 1) + yComponent
        nodeResultantY(node2, 1) = nodeResultantY(node2, 1) + yComponent
    end
    nodeResultant = sqrt(nodeResultantX.^2 + nodeResultantY.^2)./2
    
    tHigh = max(memberForces)
    cHigh = min(memberForces)
    
    if tHigh < 0
        tHigh = 0
        error('No members in tension')
    end
    
    if cHigh > 0
        cHigh = 0
        error('No members in compression')
    end
    
    cHigh = abs(cHigh)
    
    %Calculating the max Rupture in the Link
    tRupture = tHigh/(t*(w-d))
    cRupture = cHigh/(t*w)
    
    if cRupture > yeild || tRupture > yeild
        error ('Link was ruptured')
    end
    
    if cHigh >= tHigh
        fHigh = cHigh
    else
        fHigh = tHigh
    end
    
    %Bearing Failiure
    bearing = fHigh / (t*d)
    
    if bearing > yeild
        error ('Bearing stress ruined the bridge')
    end
    
    tearout = tHigh/(2*b*t)
    
    if tearout > yeild
        error ('Tearout ruined the bridge')
    end
    
    %r = ((1/12)*t*w^2)/(t*w)
    
    %buckling = (pi^2 * eMod)/((l/r)^2)
    I = (t*w^3)/12
    
    buckling = (pi^2 * eMod * I)/(l^2)
    
    buckling = buckling/(w*t)
    
    if buckling > yeild
        %error ('Buckling ruined the bridge')
    end
end

function stiffnessMatrix = generateBeamStiffnessMatrix(node1, node2, angle, numDofs, globalK, stiffnessCoefficient)
    c = cosd(angle)
    s = sind(angle)
    cs = c*s
    if node1 < node2
        index1 = node1*2 - 1
        index2 = node1*2
        index3 = node2*2 - 1
        index4 = node2*2
    else 
        error('Node indexing is incorrect')
    end
    indices = [index1 index2 index3 index4]
    specificK = zeros(numDofs)
    for x = 1:4
        for y = 1:4
            if (mod(x,2) == 1) &&(mod(y,2) == 1) && (x == y)
                specificK(indices(x), indices(y)) = c^2
            elseif (mod(x,2) == 1) &&(mod(y,2) == 1)
                specificK(indices(x), indices(y)) = -c^2
            elseif (mod(x,2) == 0) &&(mod(y,2) == 0) && (x == y)
                specificK(indices(x), indices(y)) = s^2
            elseif (mod(x,2) == 0) &&(mod(y,2) == 0)
                specificK(indices(x), indices(y)) = -s^2
            elseif (x == 1 && y == 2) || (x == 2 && y == 1) || (x == 3 && y == 4) || (x == 4 && y == 3)
                specificK(indices(x), indices(y)) = cs
            else 
                specificK(indices(x), indices(y)) = -cs
            end
        end
    end
    stiffnessMatrix = globalK + stiffnessCoefficient*specificK
end

function force = determineForce(node1, node2, angle, stiffnessCoefficient, globalDisplacementMatrix)
    if node1 < node2
        x1 = node1*2 - 1
        y1 = node1*2
        x2 = node2*2 - 1
        y2 = node2*2
    else 
        error('Node indexing is incorrect')
    end
    force = stiffnessCoefficient*((globalDisplacementMatrix(x2)-globalDisplacementMatrix(x1))*cosd(angle) + (globalDisplacementMatrix(y2)-globalDisplacementMatrix(y1))*sind(angle))
end


