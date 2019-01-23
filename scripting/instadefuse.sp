#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define MESSAGE_PREFIX "[\x02InstaDefuse\x01]"
 
Handle hcv_SafetyBlanket = null;
 
Handle hcv_InfernoDuration = null;
 
Handle hTimer_MolotovThreatEnd = null;
 
public Plugin myinfo = {
    name = "[Retakes] Instant Defuse",
    author = "B3none, Eyal282",
    description = "Allows a CT to instantly defuse the bomb when all Ts are dead and nothing can prevemt the defusal.",
    version = "1.0.0",
    url = "https://github.com/b3none"
}

public void OnPluginStart()
{
    HookEvent("bomb_begindefuse", Event_BombBeginDefuse, EventHookMode_Post);
    HookEvent("molotov_detonate", Event_MolotovDetonate);
    HookEvent("hegrenade_detonate", Event_AttemptInstantDefuse, EventHookMode_Post);
    
    HookEvent("player_death", Event_AttemptInstantDefuse, EventHookMode_PostNoCopy);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    
    hcv_SafetyBlanket = CreateConVar("instant_defuse_safety_blanket", "5.2", "Safety blanket. We don't auto defuse when the time left on the total bomb timer is < x seconds to prevent the plugin being incorrect should they jump and tap defuse.");
    
    hcv_InfernoDuration = CreateConVar("instant_defuse_inferno_duration", "7.0", "If Valve ever changed the duration of molotov, this cvar should change with it.");
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
    
    if(c4 == -1 || FindAlivePlayer(CS_TEAM_T) != 0)
    {
        return;
    }
    else if(GetEntPropFloat(c4, Prop_Send, "m_flC4Blow") - GetConVarFloat(hcv_SafetyBlanket) < GetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown"))
    {
        PrintToChatAll("%s Defuse not certain enough, Good luck defusing!", MESSAGE_PREFIX);
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
    
    SetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown", 0.0);
    SetEntPropFloat(c4, Prop_Send, "m_flDefuseLength", 0.0);
    SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
}
 
public Action Event_AttemptInstantDefuse(Handle event, const char[] name, bool dontBroadcast)
{
    int defuser = FindDefusingPlayer();
   
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
   
    int defuser = FindDefusingPlayer();
   
    if(defuser != 0)
    {
        AttemptInstantDefuse(defuser);
    }
}
 
stock int FindDefusingPlayer()
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
 
stock int FindAlivePlayer(int team)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
        {
            return i;
        }
    }
   
    return 0;
}

stock bool IsValidClient(int client)
{
    return IsClientInGame(client) && client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientAuthorized(client) && !IsFakeClient(client);
}
