function graph = prtGraphDataGenKarate
% graph = prtGraphDataGenKarate
%   Read karate.gml
%
% From the README:
%
% The file karate.gml contains the network of friendships between the 34
% members of a karate club at a US university, as described by Wayne
% Zachary in 1977.  If you use these data in your work, please cite W. W.
% Zachary, An information flow model for conflict and fission in small
% groups, Journal of Anthropological Research 33, 452-473 (1977).

baseDir = prtGraphDataDir;
gmlFile = 'karate.gml';
file = fullfile(baseDir,gmlFile);

[sparseGraph,names] = prtUtilReadGml(file);
graph = prtDataTypeGraph(sparseGraph,names);