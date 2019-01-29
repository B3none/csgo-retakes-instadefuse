#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define MESSAGE_PREFIX "[\x02InstaDefuse\x01]"
 
Handle hEndIfTooLate = null;
Handle hDefuseIfTime = null;

Handle hcv_InfernoDuration = null;
Handle hTimer_MolotovThreatEnd = null;

Handle fw_OnInstantDefusePre = null;
Handle fw_OnInstantDefusePost = null;

float g_c4PlantTime = 0.0;
 
public Plugin myinfo = {
    name = "[Retakes] Instant Defuse",
    author = "B3none, Eyal282",
    description = "Allows a CT to instantly defuse the bomb when all Ts are dead and nothing can prevent the defusal.",
    version = "1.1.0",
    url = "https://github.com/b3none"
}

public void OnPluginStart()
{
    HookEvent("bomb_begindefuse", Event_BombBeginDefuse, EventHookMode_Post);
    HookEvent("bomb_planted", Event_BombPlanted, EventHookMode_Pre);
    HookEvent("molotov_detonate", Event_MolotovDetonate);
    HookEvent("hegrenade_detonate", Event_AttemptInstantDefuse, EventHookMode_Post);
    
    HookEvent("player_death", Event_AttemptInstantDefuse, EventHookMode_PostNoCopy);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    
    hcv_InfernoDuration = CreateConVar("instant_defuse_inferno_duration", "7.0", "If Valve ever changed the duration of molotov, this cvar should change with it.");
    hEndIfTooLate = CreateConVar("instant_defuse_end_if_too_late", "1.0", "End the round if too late.", _, true, 0.0, true, 1.0);
    hDefuseIfTime = CreateConVar("instant_defuse_if_time", "1.0", "Instant defuse if there is time to do so.", _, true, 0.0, true, 1.0);
    
    // Added the forwards to allow other plugins to call this one.
    fw_OnInstantDefusePre = CreateGlobalForward("InstantDefuse_OnInstantDefusePre", ET_Event, Param_Cell, Param_Cell);
    fw_OnInstantDefusePost = CreateGlobalForward("InstantDefuse_OnInstantDefusePost", ET_Ignore, Param_Cell, Param_Cell);
}

public void OnMapStart()
{
    hTimer_MolotovThreatEnd = null;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    if(hTimer_MolotovThreatEnd != null)
    {
        CloseHandle(hTimer_MolotovThreatEnd);
        hTimer_MolotovThreatEnd = null;
    }
}

public Action Event_BombPlanted(Handle event, const char[] name, bool dontBroadcast)
{
    g_c4PlantTime = GetGameTime();
}

public Action Event_BombBeginDefuse(Handle event, const char[] name, bool dontBroadcast)
{  
    RequestFrame(Event_BombBeginDefusePlusFrame, GetEventInt(event, "userid"));
   
    return Plugin_Continue;
}

public void Event_BombBeginDefusePlusFrame(int userId)
{
    int client = GetClientOfUserId(userId);
   
    if(IsValidClient(client))
    {
    	AttemptInstantDefuse(client);
    }
}

void AttemptInstantDefuse(int client, int exemptNade = 0)
{
	if(!GetEntProp(client, Prop_Send, "m_bIsDefusing"))
	{
	    return;
	}
	
	int StartEnt = MaxClients + 1;
	
	int c4 = FindEntityByClassname(StartEnt, "planted_c4");
	
	if(c4 == -1 || HasAlivePlayer(CS_TEAM_T))
	{
	    return;
	}
	
	float c4TimeLeft = GetConVarFloat(FindConVar("mp_c4timer")) - (GetGameTime() - g_c4PlantTime);
	
	if(GetConVarInt(hEndIfTooLate) == 1 && GetEntPropFloat(c4, Prop_Send, "m_flC4Blow") < GetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown"))
	{
		if(!OnInstandDefusePre(client, c4))
		{
			return;
		}
		
		PrintToChatAll("%s There was %.1f seconds left of the bomb. T Win.", MESSAGE_PREFIX, c4TimeLeft);
		
		// Force Terrorist win because they do not have enough time to defuse the bomb.
		CS_TerminateRound(1.0, CSRoundEnd_TargetBombed);
		
		return;
	}
	else if (GetConVarInt(hDefuseIfTime) != 1 || GetEntityFlags(client) && !FL_ONGROUND)
	{
		return;
	}
	
	int ent;
	if((ent = FindEntityByClassname(StartEnt, "hegrenade_projectile")) != -1 || (ent = FindEntityByClassname(StartEnt, "molotov_projectile")) != -1)
	{
	    if(ent != exemptNade)
	    {
	        PrintToChatAll("%s There is a live nade somewhere, Good luck defusing!", MESSAGE_PREFIX);
	        return;
	    }
	}  
	else if(hTimer_MolotovThreatEnd != null)
	{
	    PrintToChatAll("%s Molotov too close to bomb, Good luck defusing!", MESSAGE_PREFIX);
	    return;
	}
	
	if(!OnInstandDefusePre(client, c4))
	{
		return;
	}
	
	PrintToChatAll("%s There was %.1f seconds left of the bomb. CT Win.", MESSAGE_PREFIX, c4TimeLeft);
	
	IncrementTeamScore(CS_TEAM_CT);
	CS_TerminateRound(1.0, CSRoundEnd_BombDefused, false);
	
	OnInstantDefusePost(client, c4);
}
 
public Action Event_AttemptInstantDefuse(Handle event, const char[] name, bool dontBroadcast)
{
    int defuser = GetDefusingPlayer();
   
    int ent = 0;
   
    if(StrContains(name, "detonate") != -1)
    {
        ent = GetEventInt(event, "entityid");
    }
    
    if(defuser != 0)
	{
        AttemptInstantDefuse(defuser, ent);
	}
}

public Action Event_MolotovDetonate(Handle event, const char[] name, bool dontBroadcast)
{
    float Origin[3];
    Origin[0] = GetEventFloat(event, "x");
    Origin[1] = GetEventFloat(event, "y");
    Origin[2] = GetEventFloat(event, "z");
   
    int c4 = FindEntityByClassname(MaxClients + 1, "planted_c4");
   
    if(c4 == -1)
    {
        return;
    }
   
    float C4Origin[3];
    GetEntPropVector(c4, Prop_Data, "m_vecOrigin", C4Origin);
   
    if(GetVectorDistance(Origin, C4Origin, false) > 150)
    {
        return;
    }
 
    if(hTimer_MolotovThreatEnd != null)
    {
        CloseHandle(hTimer_MolotovThreatEnd);
        hTimer_MolotovThreatEnd = null;
    }
   
    hTimer_MolotovThreatEnd = CreateTimer(GetConVarFloat(hcv_InfernoDuration), Timer_MolotovThreatEnd, _, TIMER_FLAG_NO_MAPCHANGE);
}
 
public Action Timer_MolotovThreatEnd(Handle timer)
{
    hTimer_MolotovThreatEnd = null;
   
    int defuser = GetDefusingPlayer();
   
    if(defuser != 0)
    {
        AttemptInstantDefuse(defuser);
    }
}

void OnInstantDefusePost(int client, int c4)
{
	Call_StartForward(fw_OnInstantDefusePost);
	
	Call_PushCell(client);
	Call_PushCell(c4);
	
	Call_Finish();
}

void IncrementTeamScore(int team)
{
	int teamScore = CS_GetTeamScore(team) + 1;
	CS_SetTeamScore(team, teamScore);
	SetTeamScore(team, teamScore);
}
 
stock int GetDefusingPlayer()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_bIsDefusing"))
        {
            return i;
        }
    }
   
    return 0;
}

stock bool OnInstandDefusePre(int client, int c4)
{
	Action response;
	
	Call_StartForward(fw_OnInstantDefusePre);
	Call_PushCell(client);
	Call_PushCell(c4);
	Call_Finish(response);
	
	return !(response != Plugin_Continue && response != Plugin_Changed);
}
 
stock bool HasAlivePlayer(int team)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
        {
            return true;
        }
    }
   
    return false;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && IsClientAuthorized(client) && !IsFakeClient(client);
}
