//******************************************************************************
// Resumen Rapido:
//*Acciones primarias:
//  El agente cuenta con una Máquina de estados finita (FSM).
//  A cada estado se le llama "accion primaria".
//  estado actual: creencia "primary_action(accion)"
//  cambiar estado: "+set_primary_action(nueva_accion)"
//
//  De momento, solo hay dos acciones primarias goto_base, guard_base
//  De momento, solo hay una transicion:
//                          target_reached
//              goto_base -----------------------> guard_base
//
//*Acciones secundarias:
//    Subtareas que realiza el agente,
//    Cuando finaliza la accion secundaria, el agente retoma la accion primaria
//    Se puede considerar una especie de "llamada a una subrutina"
//    estado actual: "secondary_action(accion)"
//    acciones secundarias: killing , helping
//
//*Ordenes del equipo y del esquadron:
//    Segun los mensajes que reciba, el agente puede decidir cambiar
//    su primary_action o realizar una secondary_action
//
//*Organización de esquadron
//    El agente apunta su lider de esquadron en "squad_leader(Leader)"
//    la funcion .getSquadLeader(Leader); devuelve el ID del lider de squadron
//******************************************************************************


//TEAM_AXIS

+flag (F): team(200)
  <-
  
  //class(X): X es la clase a la que pertenece el agente:
  // NONE = 0, SOLDIER = 1, MEDIC = 2, ENGINEER = 3,
  //FIELOPS = 4
  ?class(ClassId);
  if(ClassId == 1 ){ +my_class(soldier);};
  if(ClassId == 2 ){ +my_class(medic);};
  if(ClassId == 4 ){ +my_class(fieldops);};
  ?my_class(ClassName);
  .print("My class is (",ClassId,")" , ClassName);
  //
  +base_position(F);
  +primary_action(goto_base);
  .getSquadLeader(Leader);
  .print("My squad leader is" , Leader);
  +squad_leader(Leader).
 
//******************************************************************************
// Acciones primarias
// goto_base
// guard_base
// engage *TODO*
// return_base *TODO*

//*************************************
//continuar accion primaria
//
-secondary_action(Sa): primary_action(goto_base) | primary_action(return_base)
<-
	?primary_action(Pa);
	if(Sa == killing){} //no llenar el log de porqueria
	else {
		.print("DEBUG: Sa: ", Sa , "Ended, resuming pa: " , Pa); 
	}
	 if(base_position(_)){
	  	?base_position(P);
		if(Sa == killing){} //no llenar el log de porqueria
		else {
			.print("go to base at " , P);
		}
		.goto(P);
	 }else{
	 	.print("ERROR: action" , Pa , "But no belief base_position(P)");
	 }.
//
-secondary_action(Sa): primary_action(guard_base)
<-
	if(Sa == killing){} //no llenar el log de porqueria
	else {.print("DEBUG: Sa: ", Sa , "Ended, resuming pa: " , guard_base);}
	+start_patroll.

//*************************************
//actualiza accion primaria

//goto_base y return_base
+set_primary_action(goto_base,P)
<-
    .print("set primary action to " , goto_base , " " , P);
	if(base_position(_)){ -base_position(_); }
	+base_position(P);
	if(primary_action(_)){ -primary_action(_);}
	.goto(P);
	+primary_action(goto_base).

//guard_base
+set_primary_action(guard_base)
<-
	.print("set primary action to guard_base ");
	if(primary_action(_)){ -primary_action(_);}
	+primary_action(guard_base);
	+start_patroll.

//Transiciones entre estados
//goto_base -> guard_base
+target_reached(P) : primary_action(goto_base) & base_position(P)
<-
	+set_primary_action(guard_base).
+target_reached(P) : primary_action(goto_base) & base_position(P)
<-
	+set_primary_action(return_base).


//******************************************************************************
// Acciones secundarias

//*************************************
//Lider de nuestra patrulla solicita suministros
//Contestar solicitud.
//MEDICPACK = 1001
//AMMOPACK = 1002
+msg_ask_help_pack(1001)[source(Dest)]: my_class(medic) & not secondary_action(_) & squad_leader(Dest)
<- 
    .print(Dest, " I can give you medpack");
    .send(Dest, tell, msg_confirm_pack_boost(1001)).

+msg_ask_help_pack(1002)[source(Dest)]: my_class(fieldops) & not secondary_action(_) & squad_leader(Dest)
<- 
    .print(Dest, " I can give you ammo");
    .send(Dest, tell, msg_confirm_pack_boost(1002)).

//Aliado nos confirma posicion de entrega
+msg_confirm_pos(Pos)[source(A)]: not secondary_action(_)
<- 
	+secondary_action(helping);
    //+helping_teammate(A);
    +help_needed_pos(Pos);
	.print("Delivering pack to",Pos);
    .goto(Pos).

//Entregar medpack
+target_reached(X): my_class(medic) & secondary_action(helping) & help_needed_pos(X)
<-
    -help_needed_pos(X);
    .cure;
    //?helping_teammate(A);
    //send(A, tell, health_pack_deployed(X));
    //-helping_teammate(A);
	-secondary_action(helping).

//Entregar municion
+target_reached(X): my_class(fieldops) & secondary_action(helping) & help_needed_pos(X)
<-
	-help_needed_pos(X);
	.reload;
	-secondary_action(helping).
	
//*************************************
// accion secundaria: MATAR

+enemies_in_fov(ID,Type,Angle,Distance,Health,Position): Health > 0 & not secondary_action(_)
<-
  .stop;
  .look_at(Position);
  .shoot(3,Position);
  //.print("start secondary action KILLING");
  +secondary_action(killing).
 
-enemies_in_fov(ID,Type,Angle,Distance,Health,Position):  secondary_action(killing)
<-
	-secondary_action(killing).
  

//******************************************************************************
// Procesar los mensajes entrantes

//**************************************
//Ordenes Esquadron

+msg_goto_base(P)[source(A)]: squad_leader(A)
<-
  .print("[DEBUG] squad leader: goto_base" , P);
  +set_primary_action(goto_base,P).
+msg_guard_base[source(A)]: squad_leader(A)
<-//TODO
  .print("[DEBUG] squad leader: guard_base");
  +set_primary_action(guard_base).

+msg_goto(P)[source(A)]: squad_leader(A)
<-
  .print("[DEBUG] squad leader: goto" , P);
  .goto(P).

+msg_squad_req(N)[source(A)]: squad_leader(A)
<-
  .print("[DEBUG] squad leader req" , N);
  .send(A,tell,msg_squad_ack(N)).

+msg_patroll[source(A)]: squad_leader(A)
<-
  .print("Start patrolling");
  +start_patroll.

//**************************************
//Equipo
+msg_enemy_base_at(P)[source(A)]
<-
  .print("[DEBUG] enemy base at:" ,P);
  +enemy_base_position(P).


//******************************************************************************

+start_patroll: position(MyPos)
<-
   .create_control_points(MyPos,40,10,C);
   +control_points(C);
   .length(C,L);
   +total_control_points(L);
   if(patrolling){ -patrolling; }//Hay una forma mejor de hacer esto¿?
   +patrolling;
   if(patroll_point(_)){ -patroll_point(_); } //comentario de arriba
   +patroll_point(0).
   
+target_reached(T): patrolling
  <-
  ?patroll_point(P);
  -+patroll_point(P+1);
  -target_reached(T).

+patroll_point(P): total_control_points(T) & P<T
  <-
  ?control_points(C);
  .nth(P,C,A);
  .goto(A).

+patroll_point(P): total_control_points(T) & P==T
  <-
  -patroll_point(P);
  +patroll_point(0).

+enemies_in_fov(ID,Type,Angle,Distance,Health,Position)
<-
  .shoot(3,Position).
