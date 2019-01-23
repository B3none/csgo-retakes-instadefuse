#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required
 
Handle hcv_NoobMargin = null;
 
Handle hcv_InfernoDuration = null;
Handle hcv_InfernoDistance = null;
 
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
   
    hcv_NoobMargin = CreateConVar("instant_defuse_noob_margin", "5.2", "To prevent noobs from instantly running for their lives when instant defuse fails, instant defuse won't activate if defuse may be uncertain to the player.");
   
    hcv_InfernoDuration = CreateConVar("instant_defuse_inferno_duration", "7.0", "If Valve ever changed the duration of molotov, this cvar should change with it.");
    hcv_InfernoDistance = CreateConVar("instant_defuse_inferno_distance", "225.0", "If Valve ever changed the maximum distance spread of molotov, this cvar should change with it.");
}
 
public void OnMapStart()
{
    hTimer_MolotovThreatEnd = null;
}
 
public Action Event_RoundStart(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    if(hTimer_MolotovThreatEnd != null)
    {
        CloseHandle(hTimer_MolotovThreatEnd);
        hTimer_MolotovThreatEnd = null;
    }
}
 
public Action Event_BombBeginDefuse(Handle hEvent, const char[] Name, bool dontBroadcast)
{  
    RequestFrame(Event_BombBeginDefusePlusFrame, GetEventInt(hEvent, "userid"));
   
    return Plugin_Continue;
}
 
public void Event_BombBeginDefusePlusFrame(int userId)
{
    int client = GetClientOfUserId(userId);
   
    if(client == 0)
    {
    	return;
    }
    
    AttemptInstantDefuse(client);
}
 
void AttemptInstantDefuse(int client, int exemptNade = 0)
{
    if(!GetEntProp(client, Prop_Send, "m_bIsDefusing"))
        return;
       
    int StartEnt = MaxClients + 1;
       
    int c4 = FindEntityByClassname(StartEnt, "planted_c4");
   
    if(c4 == -1)
    {
        return;
    }
    else if(FindAlivePlayer(CS_TEAM_T) != 0)
    {
        return;
    }
    else if(GetEntPropFloat(c4, Prop_Send, "m_flC4Blow") - GetConVarFloat(hcv_NoobMargin) < GetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown"))
    {
        PrintToChatAll("\x01 \x09[\x04%s\x09]\x01 Defuse not certain enough, Good luck defusing!", "Insta-Defuse");
        return;
    }
 
    int ent;
    if((ent = FindEntityByClassname(StartEnt, "hegrenade_projectile")) != -1 || (ent = FindEntityByClassname(StartEnt, "molotov_projectile")) != -1)
    {
        if(ent != exemptNade)
        {
            PrintToChatAll("\x01 \x09[\x04%s\x09]\x01 There is a live nade somewhere, Good luck defusing!", "Insta-Defuse");
            return;
        }
    }  
    else if(hTimer_MolotovThreatEnd != null)
    {
        PrintToChatAll("\x01 \x09[\x04%s\x09]\x01 Molotov too close to bomb, Good luck defusing!", "Insta-Defuse");
        return;
    }
       
    SetEntPropFloat(c4, Prop_Send, "m_flDefuseCountDown", 0.0);
    SetEntPropFloat(c4, Prop_Send, "m_flDefuseLength", 0.0);
    SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
}
 
public Action Event_AttemptInstantDefuse(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int defuser = FindDefusingPlayer();
   
   
    int ent = 0;
   
    if(StrContains(Name, "detonate") != -1)
    {
        ent = GetEventInt(hEvent, "entityid");
    }
    
    if(defuser != 0)
	{
        AttemptInstantDefuse(defuser, ent);
	}
}

public Action Event_MolotovDetonate(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    float Origin[3];
    Origin[0] = GetEventFloat(hEvent, "x");
    Origin[1] = GetEventFloat(hEvent, "y");
    Origin[2] = GetEventFloat(hEvent, "z");
   
    int c4 = FindEntityByClassname(MaxClients + 1, "planted_c4");
   
    if(c4 == -1)
    {
        return;
    }
   
    float C4Origin[3];
    GetEntPropVector(c4, Prop_Data, "m_vecOrigin", C4Origin);
   
    if(GetVectorDistance(Origin, C4Origin, false) > GetConVarFloat(hcv_InfernoDistance))
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
 
public Action Timer_MolotovThreatEnd(Handle hTimer)
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
        if(!IsClientInGame(i))
        {
            continue;
        }
        else if(!IsPlayerAlive(i))
        {
            continue;
        }
        else if(!GetEntProp(i, Prop_Send, "m_bIsDefusing"))
        {
        	continue;
        }
           
        return i;
    }
   
    return 0;
}
 
stock int FindAlivePlayer(int Team)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
        {
            continue;
        }  
        else if(!IsPlayerAlive(i))
        {
            continue;
        }  
        else if(GetClientTeam(i) != Team)
        {
            continue;
        }
        
        return i;
    }
   
    return 0;
}
