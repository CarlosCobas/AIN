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
from pygomas.sight import Sight
from pygomas.threshold import Threshold
from pygomas.vector import Vector3D
import math

################################################################################
################################################################################

class SquadLeader(BDITroop):
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
      sqLeader = asp.Literal(str(self.name));
      if asp.unify(term.args[-1], sqLeader, intention.scope, intention.stack):
        yield
    #==================================#
    """
    .getReunionPoint(Point)
    @return Point tupla [x,y,z]
    Obtener punto de reunion de la patrulla
    al comienzo de la partida, dentro de la base amiga
    *Calcula vector mapdir = posicion_base_enemiga - posicion_base_amiga
    *Calculo puntos perpendiculares a mapdir dentro de la base amiga.
    *Asigna a cada patrulla segun numero de patrulla
    
    *NOTA:La idea es explotar el algoritmo de pathfinding para
     intentar recorrer las mismas rutas que recorre el enemigo
    """
    @actions.add(".getReunionPoint", 1)
    def _getReunionPoint(agent, term, intention):
      [name, domain] = str(self.name).split("@");
      nnum = int(name.split("_")[-1]);
      logger.success("[DBG] {} : {}".format(nnum,str(self.name)));
      ##
      enemyBase = self.map.allied_base;
      friendBase = self.map.axis_base;
      if(self.team == TEAM_ALLIED):
        enemyBase = self.map.axis_base;
        friendBase = self.map.allied_base;
      ##
      enemyBaseCenter = Vector3D(enemyBase.end);
      enemyBaseCenter.add(enemyBase.init);
      enemyBaseCenter.x *= 0.5;
      enemyBaseCenter.y *= 0.5;
      enemyBaseCenter.z *= 0.5;
      friendBaseCenter = Vector3D(friendBase.end);
      friendBaseCenter.add(friendBase.init);
      friendBaseCenter.x *= 0.5;
      friendBaseCenter.y *= 0.5;
      friendBaseCenter.z *= 0.5;
      ##logger.success("[DBG] {} {} {}".format(enemyBase.end,enemyBase.init,enemyBaseCenter));
      #Direccion hacia base enemiga
      MapDir = Vector3D(enemyBaseCenter);
      MapDir.sub(friendBaseCenter);
      MapDir.normalize();
      ##rotar 90 o -90 grados según numero patrulla
      meetingPoint = Vector3D(MapDir);
      ##logger.success("[DBG] meetingPoint  {}".format(meetingPoint));
      ##logger.success("[DBG] ANGLE {} {}".format(nnum,math.pi*0.5 + math.pi*nnum));
      pcos = math.cos( math.pi*0.5 + math.pi*nnum);
      psin = math.sin( math.pi*0.5 + math.pi*nnum);
      meetingPoint.x = MapDir.x * pcos - MapDir.z * psin;
      meetingPoint.z = MapDir.x * psin + MapDir.z * pcos;
      ##logger.success("[DBG] meetingPoint  {}".format(meetingPoint));
      ##
      baseSpan = abs(friendBase.end.x - friendBase.init.x);
      ##logger.success("[DBG] BaseSPan  {}".format(baseSpan));
      meetingPoint.x = 0.95*baseSpan*meetingPoint.x + friendBaseCenter.x;
      meetingPoint.z = 0.95*baseSpan*meetingPoint.z + friendBaseCenter.z;
      ##logger.success("[DBG] meetingPoint  {}".format(meetingPoint));
      meetingPoint.x = math.floor(meetingPoint.x);
      meetingPoint.y = math.floor(meetingPoint.y);
      meetingPoint.z = math.floor(meetingPoint.z);
      ##logger.success("[DBG] Meeting Point {}".format(meetingPoint));
      ##
      result = tuple((meetingPoint.x, meetingPoint.y, meetingPoint.z,));
      ##
      if(False == self.map.can_walk(meetingPoint.x, meetingPoint.z)):
        result = tuple((friendBase.init.x, friendBase.init.y, friendBase.init.z,));
      ##
      if asp.unify(term.args[-1], result, intention.scope, intention.stack):
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
      enemyBaseCenter = Vector3D(enemyBase.end);
      enemyBaseCenter.add(enemyBase.init);
      enemyBaseCenter.x = math.floor(enemyBaseCenter.x*0.5);
      enemyBaseCenter.y = math.floor(enemyBaseCenter.y*0.5);
      enemyBaseCenter.z = math.floor(enemyBaseCenter.z*0.5);
      basePos = tuple((enemyBaseCenter.x, enemyBaseCenter.y, enemyBaseCenter.z,));
      if asp.unify(term.args[-1], basePos, intention.scope, intention.stack):
        yield
    #==================================#
    """
    .getDropPoint(Dist,Ret)
    Posicion enfrente del agente a una distancia Dist
    Devuelve el punto en Ret
    """
    @actions.add(".getDropPoint",2)
    def getDropPoint(agent,term,intention):
      dist = asp.grounded(term.args[0], intention.scope);
      tx = self.movement.position.x + self.movement.heading.x * dist;
      ty = self.movement.position.y;
      tz = self.movement.position.z + self.movement.heading.z * dist;
      #busca drop point valido
      tx = math.floor(tx);
      ty = math.floor(ty);
      tz = math.floor(tz);
      alpha = 0.0;
      while (alpha <= 2*math.pi and False == self.map.can_walk(tx, tz)):
        alpha += 0.05;
        tx = math.cos(alpha) * self.movement.heading.x * dist;
        tx += self.movement.position.x ;
        tz = math.sin(alpha) * self.movement.heading.z * dist;
        tz += self.movement.position.z;
        tx = math.floor(tx);
        tz = math.floor(tz);
      ##
      targetPos = tuple((tx,ty,tz));
      if asp.unify(term.args[-1], targetPos, intention.scope, intention.stack):
        yield
    #==================================#
    #==================================#
    @actions.add(".countEnemiesInFov",1)
    def _countEnemiesInFov(agent, term, intention):
      enemyCount = 0;
      ##
      if asp.unify(term.args[-1], enemyCount, intention.scope, intention.stack):
        yield
