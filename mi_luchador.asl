+flag(F): team(200)
  <-
  //.create_control_points(F,500,4,C);
  // Puntos de control borde del mapa
  +control_points([[10,0,10],[246,0,10],[246,0,246],[10,0,246]]);
  ?control_points(C);
  //+control_points(C);
  .length(C,L);
  +total_control_points(L);
  
  //calcula punto de control mas cercano
  +get_closest_control_point;
  ?closest_control_point(PointIndex);
  .nth(PointIndex,C,Point);
  .print("Punto mas cercano:", PointIndex , Point);
  
  //ir al punto mas cercano
  +patrolling;
  +vueltas_mapa(0);
  +sentido_anti_horario;
  ?health(Crrnt_hlt);
  +current_health(Crrnt_hlt);
  +defensa;
  +patroll_point(PointIndex);
  .print("Got control points:", C).

//******************************************************************************
//******************************************************************************
// Anyade creencia "closest_control_point(i)"
// i = indice punto mas cercano en lista puntos control

+get_closest_control_point : position([X,Y,Z]) & X < 128 & Z < 128
  <-
  +closest_control_point(0).
+get_closest_control_point: position([X,Y,Z]) &  X >= 128 & Z < 128
  <-
  +closest_control_point(1).
+get_closest_control_point : position([X,Y,Z]) &  X >= 128 & Z >= 128
  <-
  +closest_control_point(2).
+get_closest_control_point : position([X,Y,Z]) &  X < 128 & Z >= 128
  <-
  +closest_control_point(3).

//******************************************************************************



+vueltas_mapa(X): X==2
  <-
  -defensa;
  //mi_luchador.asl:56:3: error: plan failure
  //
  ?control_points(A);
 //^~~~~~~~~~~~~~~
  -control_points(A);
  ?flag(F);
  .create_control_points(F,200,4,C);
  ?control_points(C);
  .length(C,L);
  +total_control_points(L);
  .print("Atacando").


//******************************************************************************

+target_reached(T): patrolling & team(200) & sentido_anti_horario
  <-
  .print("[DEBUG] plan target_reached sentido_anti_horario");
  ?patroll_point(P);
  -+patroll_point(P-1);
  -target_reached(T).

+target_reached(T): patrolling & team(200) & sentido_horario
  <-
  .print("[DEBUG] plan target_reached sentido_horario");
  ?patroll_point(P);
  -+patroll_point(P+1);
  -target_reached(T).


+target_reached(T): patrolling & team(200)
  <-
  .print("[DEBUG] plan target_reached");
  ?patroll_point(P);
  -+patroll_point(P+1);
  -target_reached(T).

//******************************************************************************

 +patroll_point(P): total_control_points(T) & P < 0
  <-
  -patroll_point(P);
  ?vueltas_mapa(X);
  .print("[DEBUG] patroll_point : P < 0 ");
  -+vueltas_mapa(X+1);
  +patroll_point(T-1).

+patroll_point(P): total_control_points(T) & P==T
  <-
  -patroll_point(P);
  ?vueltas_mapa(X);
  -+vueltas_mapa(X+1);
  +patroll_point(0).


+patroll_point(P): total_control_points(T) & P<T & P>=0
  <-
  ?control_points(C);
  .nth(P,C,A);
  .goto(A).
 // .print("Voy a Pos: ", A).

//******************************************************************************

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
    TYPE == 1001 & health(X) & X < 25 & not picking_health & not defensa
    <- 
    .print("voy a buscar salud");
    +picking_health;
    .goto(POS). 

+packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS): 
    TYPE == 1002 & ammo(X) & X < 25 & not picking_ammo & not defensa
    <- 
    .print("voy a buscar municion");
    +picking_ammo;
    .goto(POS). 

+health(X): X < 25 & not going_to_flag & not defensa
    <- 
    ?flag(Y);
    .print("Voy bandera por salud");
    +going_to_flag;
    .goto(Y).

+ammo(X): X < 25 & not going_to_flag & not defensa
    <- 
    ?flag(Y);
    .print("Voy bandera por ammo");
    +going_to_flag;
    .goto(Y).

+health(X) : current_health(H) & X < H & defensa & sentido_horario
  <-
  -sentido_horario;
  -+current_health(X);
  +sentido_anti_horario;
  .print("Me atacan");
  .print("sentido_anti_horario").

+health(X) : current_health(H) & X < H & defensa & sentido_anti_horario
  <-
  .print("Me atacan");
  -sentido_anti_horario;
  -+current_health(X);
  +sentido_horario;
  .print("sentido_horario").


+friends_in_fov(ID,Type,Angle,Distance,Health,Position) 
: not defensa & target(Target) & Target == ID & not picking_ammo & not picking_health
<- 
  .look_at(Position);
  .print("Objectivo fijado en Enemigo:" , ID , " " , Position);
  +target(ID);
  .shoot(9,Position);
  .goto(Position).

+friends_in_fov(ID,Type,Angle,Distance,Health,Position) 
: not defensa & not picking_ammo & not picking_health
  <-
  .look_at(Position);
  .print("Objectivo fijado en Enemigo:" , ID , " " , Position);
  +target(ID);
  .shoot(9,Position).

