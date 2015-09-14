#include <matchplugin_ins>
#include <colors>
#include <sdktools>
#include <sdkhooks>
/*
 * Thanks to Jared Ballou <sourcemod@jballou.com> for Insurgency weapon restriction code snippets
 *
 */
public Plugin:myinfo ={
	name = "Match Plugin Pistol Round",
	author = "Aphex <steamfor@gmail.com>",
	description = "Pistol Round for Insurgency Match Plugin",
	version = "0.9.1",
	url = "http://www.sourcemod.net/"
};

enum MPINS_PR_Status{
	NONE,
	LIVE,
	ENDED
};
new MPINS_PR_Status:g_pr_status;
enum MPINS_PR_TeamWant{
	STAY,
	SWITCH,
	ANY
};
new MPINS_PR_TeamWant:g_pr_teams[TEAM];
new TEAM:g_winner;


new ConVar:CVAR_pistolround_enabled_default;
new ConVar:CVAR_matchplugin_cmd_prefix;
new bool:g_pistolround_enabled;

public void OnPluginStart(){
	CreateCVARs();
}
public void OnAllPluginsLoaded(){
	new Handle:ch = GetMyHandle();
	MPINS_Native_RegCmd("pr",			"cmd_fn_pr_pr", ch);
	MPINS_Native_RegCmd("pistolround",	"cmd_fn_pr_pr", ch);
	CVAR_matchplugin_cmd_prefix = FindConVar("sm_matchplugin_cmd_prefix");
}
public void OnConfigsExecuted(){
	g_pistolround_enabled = GetConVarBool(CVAR_pistolround_enabled_default);
}


public CreateCVARs(){
	CVAR_pistolround_enabled_default = CreateConVar("sm_matchplugin_pistolround_enabled_default", "1", "Default pistol round state");
	AutoExecConfig(true);
}

public PR_HookEvents(){
	HookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("weapon_pickup", GameEvents_WeaponPickup);
	HookEvent("weapon_deploy", GameEvents_WeaponDeploy);
	HookEvent("player_first_spawn", GameEvents_PlayerSpawn);
	HookEvent("player_spawn", GameEvents_PlayerSpawn);
}
public PR_UnhookEvents(){
	UnhookEvent("round_start", GameEvents_RoundStart,  EventHookMode_PostNoCopy);
	UnhookEvent("round_end", GameEvents_RoundEnd,  EventHookMode_PostNoCopy);
	UnhookEvent("weapon_pickup", GameEvents_WeaponPickup);
	UnhookEvent("weapon_deploy", GameEvents_WeaponDeploy);
	UnhookEvent("player_first_spawn", GameEvents_PlayerSpawn);
	UnhookEvent("player_spawn", GameEvents_PlayerSpawn);
}

public MPINS_OnHelpCalled(client){
	PrintToConsole(client, " pr 1/0          enable/disable pistol round");
	PrintToConsole(client, " pr PREFERENCE   team preference stay|switch|any");
}

public change_status(MPINS_PR_Status:new_status){
	if(g_pr_status == new_status)
		return;
	g_pr_status = new_status;
	if(new_status == MPINS_PR_Status:NONE) PR_on_reset();
	else if(new_status == MPINS_PR_Status:LIVE) PR_on_live();
	else if(new_status == MPINS_PR_Status:ENDED) PR_on_ended();
}
public pr_reset(){
	for(new TEAM:i; i<TEAM;i++){
	    g_pr_teams[i] = STAY;
	}
	g_winner = SPECTATORS;
	PR_UnhookEvents();
}

public PR_on_reset(){
	pr_reset();
}
public PR_on_live(){
	decl String:cmd_prefix[10];
	CVAR_matchplugin_cmd_prefix.GetString(cmd_prefix, sizeof(cmd_prefix));
	CPrintToChatAll("[%s] Type {lightgreen}%s pr switch|stay|any {default} to select team preference", CHAT_PFX, cmd_prefix);
	CPrintToChatAll("{lightgreen}PISTOL ROUND\nLIVE");
	PR_HookEvents();
}
public PR_on_ended(){
	PrintToServer("[%s] Pistol round ended", CHAT_PFX);
	PrintToChatAll("[%s] Pistol round ended", CHAT_PFX);
	new TEAM:looser = (g_winner == SECURITY) ? INSURGENTS : SECURITY;
	if(g_pr_teams[g_winner] == SWITCH){
		PrintToChatAll("[%s] Teams will be switched", CHAT_PFX);
		InsertServerCommand("mp_switchteams");
	}else if((g_pr_teams[g_winner] == ANY) && (g_pr_teams[looser] == SWITCH)){
		PrintToChatAll("[%s] Teams will be switched", CHAT_PFX);
		InsertServerCommand("mp_switchteams");
	}
	pr_reset();
	ServerExecute();
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(MPINS_MatchStatus:LIVE_ON_RESTART);
}

public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	if(new_status == MPINS_MatchStatus:WAITING){
		change_status(MPINS_PR_Status:NONE);
	}else if(new_status == MPINS_MatchStatus:LIVE){
		if(g_pistolround_enabled){
			if(g_pr_status == MPINS_PR_Status:NONE){
				change_status(MPINS_PR_Status:LIVE);
				new_status = MPINS_MatchStatus:MODULE_HANDLED;
				return Plugin_Stop;
			}else if(g_pr_status == MPINS_PR_Status:LIVE){
				new_status = MPINS_MatchStatus:MODULE_HANDLED;
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}


public GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	if(g_pr_status == MPINS_PR_Status:NONE){
		change_status(MPINS_PR_Status:LIVE);
	}
}
public GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	if(g_pr_status == MPINS_PR_Status:LIVE){
		g_winner = TEAM:GetEventInt(event, "winner");
		change_status(MPINS_PR_Status:ENDED);
	}
}
public Action:GameEvents_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast){
	new userId = GetEventInt(event, "userid");
	if(userId > 0){
		new user = GetClientOfUserId(userId);
		if(user){
			new primary = GetPlayerWeaponSlot(user, 0);
			if(IsValidEntity(primary)){
				RemovePlayerItem(user, primary);
				AcceptEntityInput(primary, "kill");
			}
		}
	}
	return Plugin_Continue;
}
public Action:GameEvents_WeaponDeploy(Handle:event, const String:name[], bool:dontBroadcast){
	new userId = GetEventInt(event, "userid");
	if(userId > 0){
		new user = GetClientOfUserId(userId);
		if(user){
			return StripWeapons(user);
		}
	}
	return Plugin_Continue;
}
public Action:GameEvents_WeaponPickup(Handle:event, const String:name[], bool:dontBroadcast){
	new userId = GetEventInt(event, "userid");
	if(userId > 0){
		new user = GetClientOfUserId(userId);
		if(user){
			return StripWeapons(user);
		}
	}
	return Plugin_Continue;
}



public Action:StripWeapons(client){
   	if(!IsClientInGame(client))
		return Plugin_Continue;
	new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(weapon < 0)
		return Plugin_Continue;
	new String:weapon_name[32];

	GetEdictClassname(weapon, weapon_name, sizeof(weapon_name));
	if (!StrEqual(weapon_name, "weapon_m9") &&
		!StrEqual(weapon_name, "weapon_m45") &&
		!StrEqual(weapon_name, "weapon_makarov") &&
		!StrEqual(weapon_name, "weapon_m1911") &&
		!StrEqual(weapon_name, "weapon_kabar") &&
		!StrEqual(weapon_name, "weapon_gurkha")
		){
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "kill");
		new slot3 = GetPlayerWeaponSlot(client, 3);
		if(IsValidEntity(slot3)){
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", slot3);
			ChangeEdictState(client, FindDataMapOffs(client, "m_hActiveWeapon"));
		}
		new slot2 = GetPlayerWeaponSlot(client, 2);
		if(IsValidEntity(slot2)){
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", slot2);
			ChangeEdictState(client, FindDataMapOffs(client, "m_hActiveWeapon"));
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public cmd_fn_pr_pr(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	new String:cur_pref_s[32];
	if(g_pr_teams[team] == STAY)		strcopy(cur_pref_s, sizeof(cur_pref_s), "stay");
	else if(g_pr_teams[team] == SWITCH)	strcopy(cur_pref_s, sizeof(cur_pref_s), "switch");
	else strcopy(cur_pref_s, sizeof(cur_pref_s), "any");

	new String:pref[32];
	if(m_args.Length < 3){
		decl String:cmd_prefix[10];
		CVAR_matchplugin_cmd_prefix.GetString(cmd_prefix, sizeof(cmd_prefix));
		CPrintToChat(client, "[%s] Current preference: {lightgreen}%s{default} Select your team preference: {lightgreen}%s pr stay|switch|any", CHAT_PFX, cur_pref_s, cmd_prefix);
		return;
	}
	m_args.GetString(2, pref, sizeof(pref));

	if(StrEqual(pref, "0") || StrEqual(pref, "off", false)){
		if(g_pr_status == MPINS_PR_Status:LIVE){
			PrintToChat(client, "[%s] Pistol round already stared", CHAT_PFX);
			return;
		}
		CPrintToChatAll("[%s] Pistol round disabled", CHAT_PFX);
		g_pistolround_enabled = false;
		return;
	}else if(StrEqual(pref, "1") || StrEqual(pref, "on", false)){
		CPrintToChatAll("[%s] Pistol round enabled", CHAT_PFX);
		g_pistolround_enabled = true;
		return;
	}else if(StrEqual(pref, "stay") || StrEqual(pref, "st")){
		g_pr_teams[team] = STAY;
	}else if(StrEqual(pref, "switch") || StrEqual(pref, "sw")){
		g_pr_teams[team] = SWITCH;
	}else if(StrEqual(pref, "any") || StrEqual(pref, "a")){
		g_pr_teams[team] = ANY;
	}else{
		CPrintToChat(client, "[%s] Current preference: {lightgreen}%s{default} Preferences: stay|switch|any", CHAT_PFX, cur_pref_s);
		return;
	}
	if(g_pr_teams[team] == STAY)		strcopy(cur_pref_s, sizeof(cur_pref_s), "stay");
	else if(g_pr_teams[team] == SWITCH)	strcopy(cur_pref_s, sizeof(cur_pref_s), "switch");
	else strcopy(cur_pref_s, sizeof(cur_pref_s), "any");
	CPrintToChat(client, "[%s] New preference: {lightgreen}%s{default}", CHAT_PFX, cur_pref_s);
}
