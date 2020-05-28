//TEAM_AXIS

+flag (F): team(200)
  <-
  .getSquadLeader(Leader);
  .print("My squad leader is" , Leader);
  .register_service("leader");
  +squad_leader(Leader);
  //Transmite posicion base enemiga
  .getEnemyBase(EnemyBase);
  +send_msg(msg_enemy_base_at(EnemyBase));
  +enemy_base_position(EnemyBase);
  //Comienza la operacion del esquadron
  .getReunionPoint(RePoint);
  +start_grouping_squad.
  //+test_ammopack_request.
  //+test_medpack_request.

//******************************************************************************
//Envio de mensajes

+send_msg(Msg)
<-
  //Nota: .get_service actualiza axis 
  //       pero no genera evento +axis(_) si axis(_) ya existe (¿?)
  if(axis(_))
  { -axis(_) }
  //si mensajes pendientes entonces se ha llamado a .get_service anteriormente
  if(not pending_msg(_))
  { .get_service("axis");}
  +pending_msg(Msg).

//Envia todos los mensajes en cola de salida
+axis(Dest): pending_msg(_)
<-
  .findall(Msg,pending_msg(Msg),MsgList);
  for(.member(M,MsgList))
  {
    .send(Dest,tell,M);
    .print("[DEBUG] sent",M);
    -pending_msg(M);
  };
  .print("[DEBUG] all pending msg sent").
 
//*******************************************************************************
//Responder mensajes

+msg_squad_ack(_)[source(A)]
<-
  .print("squad_ack from ",A);
  if(squadMembers(_)){
    ?squadMembers(List);
    .concat(List,[A],NewList);
    -+squadMembers(NewList);
    .print("Squad members:" , NewList);
  }else{
    +squadMembers([A]);
  }.

//*******************************************************************************
//Responder solicitud de apoyo
+ask_for_backup[source(A)]: not helping
<-
  .print("Ofreciendo ayuda");
  ?position(MY_POS);
  .send(A, tell, backup_details(MY_POS)).

+come_help_me(P)[source(A)]:not helping
<-
  .stop;
  -going_to_EnemyBase;
  +send_msg(msg_goto_base(P));
  +helping;
  .goto(P).
 
//****************************************************************************//
//pedir suministros
//****************************************************************************//

// MEDICPACK = 1001
// AMMOPACK  = 1002

//+health(X) : X < 25 & primary_action(guard_base) & not waiting_pack(_) & not waiting_response
//+test_medpack_request
+request_medpack
<-
	+start_patroll;
	?health(H);
	if(H > 90)
	{}
	else
	{ +request_pack(1001);}.

//+ammo(X) : X < 25 & primary_action(guard_base) & not waiting_pack(_) & not waiting_response
//+test_ammopack_request
+request_ammopack
<-
	+start_patroll; 
	?ammo(A);
	if(A > 90)
	{}
	else
	{ +request_pack(1002);}.

//*************************************//
+request_pack(PackId): not waiting_pack(PackId) & not waiting_response
<-
    -request_pack(PackId);
	?health(H);
    ?ammo(M);
    if(PackId == 1001){
      .print("Health:",H, "Ammo:",M, " Requesting: Medpack");
    }else{
      .print("Health:",H, "Ammo:",M, " Requesting: AmmoPack");
    }
	+send_msg(msg_ask_help_pack(PackId));
    +waiting_response.

	
//*************************************//
+msg_confirm_pack_boost(PackId)[source(Doc)]: waiting_response & not waiting_pack(_)
<-
    .stop;
    .turn(3.1415);
    .getDropPoint(10,DropPos);
    .send(Doc, tell, msg_confirm_pos(DropPos));
     if(PackId == 1001){
      .print("Wating medpack from Dr." , Doc , " at " , DropPos);
    }else{
       .print("Wating ammopack from " , Doc , " at " , DropPos);
    }
    -waiting_response;
    +waiting_pack(PackId).

//*************************************//
+packs_in_fov(_, PackId, _, _, _, Pos ): waiting_pack(PackId)
<-
  .goto(Pos);
  .print("Picking up pack at ",Pos);
  +picking_up_supply(PackId);
  -waiting_pack(PackId).

 //*************************************//
+target_reached(T): picking_up_supply(PackId)
<-
  -picking_up_supply(PackId);
  +start_patroll.
  
 
//****************************************************************************//
// Controla esquadron
//****************************************************************************//

//Comienza a agrupar el esquadron
+start_grouping_squad : position(MyPos)
<-
  .print("Grouping squad members");
  //.create_control_points(MyPos,40,1,C);
  //.nth(0,C,MeetingPoint);
  .getReunionPoint(MeetingPoint);
  +send_msg(msg_goto(MeetingPoint));
  +send_msg(msg_squad_req(0));
  .goto(MeetingPoint);
  +grouping_squad.

//Liderar esquadron hacia base enemiga
+target_reached(T): grouping_squad
  <-
  -grouping_squad;
  .wait(2000);//Esperar al resto de miembros
  .print("Squad going to enemy base");
  .getEnemyBase(EnemyBase);
  +send_msg(msg_goto_base(EnemyBase));
  +going_to_EnemyBase;
  .goto(EnemyBase).
  //+test_ammopack_request.

//Vuelve a base enemiga luego de ayudar
+target_reached(T): helping
  <-
  -helping;
  .wait(1000);//Esperar al resto de miembros
  .print("Squad going to enemy base");
  .getEnemyBase(EnemyBase);
  +send_msg(msg_goto_base(EnemyBase));
  +going_to_EnemyBase;
  .goto(EnemyBase).
  //+test_ammopack_request.

//Defiende base enemiga
+target_reached(T): going_to_EnemyBase
<-
  -going_to_EnemyBase;
  .print("Securing enemy base");
  +send_msg(msg_guard_base);
  +request_medpack;
  +request_ammopack.
  
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
