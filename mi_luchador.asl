//EJEMPLO LUCHADOR 

+flag(F): team(200)
  <-
  .create_control_points(F,500,4,C);
  +control_points(C);
  //.wait(5000);
  .length(C,L);
  +total_control_points(L);
  +patrolling;
  +patroll_point(0);
  .print("Got control points:", C).


+target_reached(T): patrolling & team(200)
  <-
  ?patroll_point(P);
  -+patroll_point(P+1);
  -target_reached(T).

+patroll_point(P): total_control_points(T) & P<T
  <-
  ?control_points(C);
  .nth(P,C,A);
  .goto(A).
 // .print("Voy a Pos: ", A).

+patroll_point(P): total_control_points(T) & P==T
  <-
  -patroll_point(P);
  +patroll_point(0).

+pack_taken(TYPE, N):
    TYPE == 1001 & picking_health
    <- 
    -picking_health.

+pack_taken(TYPE, N):
    TYPE == 1002 & picking_ammo
    <- 
    -picking_ammo.

+target_reached(POS): flag(FLAG_POS) & POS == FLAG_POS
    <-
    -going_to_flag.

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS): 
    TYPE == 1001 & health(X) & X < 25 & not picking_health
    <- 
    .print("voy a buscar salud");
    +picking_health;
    .goto(POS). 

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS): 
    TYPE == 1002 & ammo(X) & X < 25 & not picking_ammo
    <- 
    .print("voy a buscar municion");
    +picking_ammo;
    .goto(POS). 

+health(X): X < 25 & not going_to_flag
    <- 
    ?flag(Y);
    .print("Voy bandera por salud");
    +going_to_flag;
    .goto(Y).

+ammo(X): X < 25 & not going_to_flag
    <- 
    ?flag(Y);
    .print("Voy bandera por ammo");
    +going_to_flag;
    .goto(Y).

+friends_in_fov(ID,Type,Angle,Distance,Health,Position)
  <-
  .shoot(9,Position).