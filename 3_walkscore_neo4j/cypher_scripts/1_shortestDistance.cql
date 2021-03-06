// ------------------------------------------------------------------
// Neo4j Spatial Experiments, December 2018
// Written by Menome Technologies Inc. http://www.menome.com
//
// Cypher Version of the Walk Score Calculation 
// ------------------------------------------------------------------

// 6 compute walk score Walk Score® = Raw Score x 6.67 - (ID - ABL)
// Can use any lat/long or pre-configured Buildings Test 1, Test 2, Test 3
match (d:Building {Code:'Test 1'}) 
with d,point({ longitude: d.lon, latitude: d.lat }) as p1 


// find all points of interest in boundary
match (p2:PointOfInterest)-[]-(t:OSMTags)  where distance(p1,p2.location) <= 1600 and p2.name="Murrieta's Bar & Grill"
with p2,d,p1
match p=shortestPath((d)-[:ROUTE*..100]-(p2))
return p// ------------------------------------------------------------------
// Neo4j Spatial Experiments, December 2018
// Written by Menome Technologies Inc. http://www.menome.com
//
// Cypher Version of the Walk Score Calculation 
// ------------------------------------------------------------------

// 6 compute walk score Walk Score® = Raw Score x 6.67 - (ID - ABL)
// Can use any lat/long or pre-configured Buildings Test 1, Test 2, Test 3
match (d:Building {Code:'Test 1'}) 
with d,point({ longitude: d.lon, latitude: d.lat }) as p1 
// get all intersections in the area around Calgary
match (i:Intersection) where distance(p1,i.location) <= 10000 
with p1,d,count(i)/3.1502 as ID

// determine ID Penality
with p1,d,ID,
CASE 
    WHEN ID <= 60 then 0.05
    WHEN ID > 60 and ID <=90 then .04
    WHEN ID > 90 and ID <=120 then .03
    WHEN ID > 150 and ID <= 200 then .01
    ELSE 0.0
END as IDPenalty

// compute ABL Penalty
match (i:Intersection) where distance(p1,i.location) <= 10000 
with d,p1,IDPenalty,i, collect(i) as intersections
unwind intersections as i1
match (i1)-[r:ROUTE]->(i2:Intersection)
with d,p1,IDPenalty,avg(r.distance) as ABL

with ABL,p1,d,IDPenalty,
CASE 
    WHEN ABL <= 120 then 0.0
    WHEN ABL > 120 and ABL <=150 then .01
    WHEN ABL > 150 and ABL <=165 then .02
    WHEN ABL > 165 and ABL <= 180 then .03
    WHEN ABL > 180 and ABL <= 195 then .04
    ELSE .05
END as ABLPenalty

// compute walk score
with p1,d,IDPenalty,ABLPenalty

// find all points of interest in boundary
match (p2:PointOfInterest)-[]-(t:OSMTags) where distance(p1,p2.location) <= 1600 

with p1,d,IDPenalty,ABLPenalty,collect(p2) as points

unwind (points) as point

// find path to shortest distance
match p=shortestPath((d)-[rels:ROUTE*..100]-(point))

with point,p1,d,IDPenalty,ABLPenalty, REDUCE(s = 0, r IN rels | s + r.distance) AS distanceTo

// compute walk score using weighted boundaries
with point,p1,d,IDPenalty,ABLPenalty,
CASE 
    when distanceTo <= 400 then point.RawScore
    when distanceTo > 400 and distanceTo <= 800 then point.RawScore * 0.75
    when distanceTo > 800 and distanceTo <= 1200 then point.RawScore * 0.40
    when distanceTo > 1200 and distanceTo <= 1600 then point.RawScore * 0.125
    else 0
END as rawScore

with p1,d,IDPenalty,ABLPenalty,sum(rawScore) as totalRawScore

with IDPenalty,ABLPenalty,totalRawScore,
// Check rawscore total - 15 is max
CASE 
    when totalRawScore > 15.0 then 15.0 * 6.67
    else totalRawScore * 6.67
END as score

return (score - (IDPenalty * score + ABLPenalty * score)) as WalkScore, IDPenalty,ABLPenalty