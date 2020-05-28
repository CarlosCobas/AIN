import json
import random
from collections import deque

import agentspeak as asp
from agentspeak.stdlib import actions as asp_action
from loguru import logger
from numpy import arctan2, cos, sin
from spade.behaviour import OneShotBehaviour, PeriodicBehaviour, CyclicBehaviour
from spade.message import Message
from spade.template import Template
from spade_bdi.bdi import BDIAgent
from pygomas.bditroop import BDITroop

from agentspeak import Actions
from agentspeak import grounded
from agentspeak.stdlib import actions as asp_action
from pygomas.ontology import DESTINATION
from pygomas.agent import LONG_RECEIVE_WAIT

from pygomas.agent import AbstractAgent, LONG_RECEIVE_WAIT
from pygomas.config import (
    Config,
    MIN_POWER,
    MAX_POWER,
    POWER_UNIT,
    MIN_STAMINA,
    MAX_STAMINA,
    STAMINA_UNIT,
    MIN_AMMO,
    MAX_AMMO,
    MIN_HEALTH,
    MAX_HEALTH,
    TEAM_NONE,
    TEAM_ALLIED,
    TEAM_AXIS,
    PRECISION_Z,
    PRECISION_X,
)
from pygomas.jps import JPSAlgorithm
from pygomas.map import TerrainMap
from pygomas.mobile import Mobile
from pygomas.ontology import (
    AIM,
    ANGLE,
    DEC_HEALTH,
    DISTANCE,
    FOV,
    HEAD_X,
    HEAD_Y,
    HEAD_Z,
    MAP,
    PACKS,
    QTY,
    SHOTS,
    VEL_X,
    TYPE,
    VEL_Y,
    VEL_Z,
    X,
    Y,
    Z,
    PERFORMATIVE,
    PERFORMATIVE_CFA,
    PERFORMATIVE_CFB,
    PERFORMATIVE_CFM,
    PERFORMATIVE_DATA,
    PERFORMATIVE_GAME,
    PERFORMATIVE_GET,
    PERFORMATIVE_INIT,
    PERFORMATIVE_MOVE,
    PERFORMATIVE_OBJECTIVE,
    PERFORMATIVE_SHOOT,
    AMMO_SERVICE,
    BACKUP_SERVICE,
    MEDIC_SERVICE,
    AMMO,
    BASE,
    CLASS,
    DESTINATION,
    ENEMIES_IN_FOV,
    FRIENDS_IN_FOV,
    FLAG,
    HEADING,
    HEALTH,
    NAME,
    MY_MEDICS,
    MY_FIELDOPS,
    MY_BACKUPS,
    PACKS_IN_FOV,
    PERFORMATIVE_PACK_TAKEN,
    PERFORMATIVE_TARGET_REACHED,
    PERFORMATIVE_FLAG_TAKEN,
    POSITION,
    TEAM,
    THRESHOLD_HEALTH,
    THRESHOLD_AMMO,
    THRESHOLD_AIM,
    THRESHOLD_SHOTS,
    VELOCITY,
)
from pygomas.pack import PACK_MEDICPACK, PACK_AMMOPACK, PACK_OBJPACK, PACK_NONE
from pygomas.bditroop import BDITroop
from pygomas.bdisoldier import BDISoldier
from pygomas.bdimedic import BDIMedic
from pygomas.bdifieldop import BDIFieldOp
from pygomas.sight import Sight
from pygomas.threshold import Threshold
from pygomas.vector import Vector3D
import math

################################################################################
################################################################################

class SquadSoldier(BDISoldier):
  def add_custom_actions(self,actions):
    super().add_custom_actions(actions)
    #==================================#
    """
    .getSquadLeader(leaderID)
    Asignar escuadron en función del JID
    devuelve literal en variable "leaderID"
    *NOTA:
      los JID de los agentes deben respetar
      la siguiente convencion para que este metodo funcione
      equipo_rol_usuario_num@dominio
      equipo = axis , alied , etc..
      rol = fieldop, medic, soldier,squadleader, etc..
      usuario = todos los agentes del equipo necesitan el mismo
      nnum = numero del agente (pygomas lo añade automatico)
    """
    @actions.add(".getSquadLeader", 1)
    def _getSquadLeader(agent, term, intention):
      ##
      SQUAD_SIZE = 3 #soldados por escuadra
      LEADER_ROLE = "squadleader"
      [name, domain] = str(self.name).split("@");
      [team, role , user, nnum] = name.split("_");
      if len(name.split("_")) != 4:
        logger.success("ERROR: {} debe ser equipo_rol_usuario_num".format(name));
      nnum = int(name.split("_")[-1]);
      #en funcion del numero de agente, asigna lider
      #nos hacemos un "Round-robin"
      leaderID = "nil";
      squadNum =  nnum % SQUAD_SIZE;
      leaderID = team+"_"+LEADER_ROLE+"_"+user+"_"+str(squadNum)+"@"+domain;
      #cadena a literal y "groundea" valor al primer parametro
      sqLeader = asp.Literal(leaderID);
      if asp.unify(term.args[-1], sqLeader, intention.scope, intention.stack):
        yield
    #==================================#
    """
    Convierte cadena a termino
    """
    @actions.add(".string2term", 2)
    def _string2term(agent, term, intention):
      string = asp.grounded(term.args[0], intention.scope)
      result = asp.Literal(string)
      logger.success("[DBG] {} -> {}".format(string,result));
      if asp.unify(term.args[-1], result, intention.scope, intention.stack):
        yield
    #==================================#
    """
    Get Enemy base
    """
    @actions.add(".getEnemyBase",1)
    def _getEnemyBase(agent, term, intention):
      enemyBase = self.map.allied_base;
      if(self.team == TEAM_ALLIED):
        enemyBase = self.map.axis_base;
      basePos = tuple((enemyBase.init.x, enemyBase.init.y, enemyBase.init.z,));
      if asp.unify(term.args[-1], basePos, intention.scope, intention.stack):
        yield
    #==================================#
    #==================================#
    @actions.add(".countEnemiesInFov",1)
    def _countEnemiesInFov(agent, term, intention):
      enemyCount = 0;
      ##
      if asp.unify(term.args[-1], enemyCount, intention.scope, intention.stack):
        yield
    #==================================#
    """
    Get closest Point
    """
    @actions.add(".getClosestPoint", 2)
    def _getClosestPoint(agent, term, intention):
      agentPos = tuple((self.movement.position.x, self.movement.position.y, self.movement.position.z,))
      backUpPos = asp.grounded(term.args[0], intention.scope)
      logger.success( "[{}] Recieved Positions: {}".format(self.jid.localpart, backUpPos) )
      closestIndex = 0
      minDist = 10000000
      i = 0      
      while i < len(backUpPos):
        pos = backUpPos[i]
        x = (pos[0] - agentPos[0]) * (pos[0] - agentPos[0])
        y = (pos[1] - agentPos[1]) * (pos[1] - agentPos[1])
        z = (pos[2] - agentPos[2]) * (pos[2] - agentPos[2])
        realDist = math.sqrt(x+y+z)
        if(realDist < minDist):
          minDist = realDist
          closestIndex = i
        i+=1

      if asp.unify(term.args[-1], closestIndex, intention.scope, intention.stack):
        yield
    
