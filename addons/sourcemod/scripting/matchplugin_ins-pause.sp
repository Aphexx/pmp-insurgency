#include <matchplugin_ins>
#include <colors>

public Plugin:myinfo ={
	name = "Match Plugin Pause",
	author = "Aphex <steamfor@gmail.com>",
	description = "Pause for Insurgency Match Plugin",
	version = "0.9.5",
	url = "http://www.sourcemod.net/"
};

new ConVar:CVAR_matchplugin_disconnect_autopause;
new ConVar:CVAR_matchplugin_pause_team_limit;
new ConVar:CVAR_matchplugin_pause_time_limit;
new ConVar:CVAR_matchplugin_pause_delay_nextround;


new const String:WaitingForUnpause[] = "pause_unpause";
new const String:WaitingForUnpauseDescr[] = "game unpause";

enum PAUSE_STATE{
	NONE,
	NOT_PAUSED,
	PAUSED,
	UNPAUSING,
	DELAYED
};
new PAUSE_STATE:g_paused = NOT_PAUSED;
new g_team_limits[TEAM];
new g_time_limits[TEAM];
new g_time_limit_force;
new bool:g_team_pause_req[TEAM];
new TEAM:g_pauser;
new Handle:g_unpause_timer;



new const g_timer_prec = 10;
new const g_timer_min = 30;
new const g_timer_force_unpause = 30;


public void OnPluginStart(){
	CVAR_matchplugin_disconnect_autopause = CreateConVar("sm_matchplugin_disconnect_autopause",		"1",	"If enabled, game will be autopaused when players disconnects from server during the match");
	CVAR_matchplugin_pause_team_limit = 	CreateConVar("sm_matchplugin_pause_team_limit",			"-1",	"Pause limit per team; -1 for no limit");
	CVAR_matchplugin_pause_time_limit = 	CreateConVar("sm_matchplugin_pause_time_limit",			"-1",	"Pause time limit in seconds after what game will be automaticly unpaused; -1 for no limit");
	CVAR_matchplugin_pause_delay_nextround =CreateConVar("sm_matchplugin_pause_delay_nextround",	"0",	"Disallow ingame pause and delay all pauses till next round start");
	AutoExecConfig(true);

	RegConsoleCmd("say", Command_say);
	RegConsoleCmd("say_team", Command_say_team);
	HookEvent("round_start",	GameEvents_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",		GameEvents_RoundEnd,	EventHookMode_PostNoCopy);
}


public void OnAllPluginsLoaded(){
	new Handle:ch = GetMyHandle();
	MPINS_Native_RegCmd("p",				"cmd_fn_pause_pause", ch);
	MPINS_Native_RegCmd("pause",			"cmd_fn_pause_pause", ch);
	MPINS_Native_RegCmd("up",				"cmd_fn_pause_unpause", ch);
	MPINS_Native_RegCmd("unpause",			"cmd_fn_pause_unpause", ch);
	MPINS_Native_RegCmd("cp",				"cmd_fn_pause_cancel", ch);
	MPINS_Native_RegCmd("cancelpause",	   	"cmd_fn_pause_cancel", ch);
}

public OnClientDisconnect(client){
	if(!IsClientInGame(client))
		return;
	new TEAM:team = TEAM:GetClientTeam(client);
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	if((match_status == LIVE || match_status == MODULE_HANDLED) && g_paused == NOT_PAUSED){
		if(!CVAR_matchplugin_disconnect_autopause.BoolValue)
			return;
		CPrintToChatAll("[%s] Autopausing game due player disconnecting", CHAT_PFX);
		CPrintToChatAll("[%s] In order to reconnect to server the game has to be unpaused", CHAT_PFX);
		new Handle:cv_password = FindConVar("sv_password");
		new String:password[100];
		GetConVarString(cv_password, password, sizeof(password));
		CPrintToChatAll("[%s] Password: {green}%s", CHAT_PFX, password);
		pause(team);
		return;
	}
}

public Action:Command_say(client, args){
	if(client <= 0 || client > MaxClients)
		return Plugin_Continue;
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	new TEAM:team = TEAM:GetClientTeam(client);
	if(g_paused == PAUSE_STATE:PAUSED || g_paused == PAUSE_STATE:UNPAUSING){
		if(team == INSURGENTS)
			CPrintToChatAll("{blue}%N: {default}%s", client, message);
		else if(team == SECURITY)
			CPrintToChatAll("{red}%N: {default}%s", client, message);
		else
			CPrintToChatAll("*SPEC* %N: %s", client, message);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action:Command_say_team(client, args){
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);

	if(g_paused == PAUSE_STATE:PAUSED || g_paused == PAUSE_STATE:UNPAUSING){
		new TEAM:team = TEAM:GetClientTeam(client);
		new TEAM:r_team;
		for(new i = 1; i <= MaxClients; i++){
			if(IsClientInGame(i) && !IsFakeClient(i)){
				r_team = TEAM:GetClientTeam(i);
				if(r_team == team || r_team == SPECTATORS){
					if(team == INSURGENTS){
						CPrintToChat(i, "{blue}(Insurgents) %N: {default}%s", client, message);
					}else if(team == SECURITY){
						CPrintToChat(i, "{red}(Security) %N: {default}%s", client, message);
					}else{
						CPrintToChat(i, "*SPEC* %N: %s", client, message);
					}
				}
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	if(!CVAR_matchplugin_pause_delay_nextround.BoolValue)
		return Plugin_Continue;
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	if((match_status == LIVE || match_status == MODULE_HANDLED) && g_paused == NOT_PAUSED){
		if(g_team_pause_req[SECURITY]){
			for(new TEAM:t; t<TEAM;t++){
				g_team_pause_req[t] = false;
			}
			pause_request(0, SECURITY);
		}else if(g_team_pause_req[INSURGENTS]){
			for(new TEAM:t; t<TEAM;t++){
				g_team_pause_req[t] = false;
			}
			pause_request(0, INSURGENTS);
		}
	}
	return Plugin_Continue;
}
public Action:GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	if(!CVAR_matchplugin_pause_delay_nextround.BoolValue)
		return Plugin_Continue;
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	if((match_status == LIVE || match_status == MODULE_HANDLED) && g_paused == NOT_PAUSED){
		if(g_team_pause_req[SECURITY]){
			CPrintToChatAll("[%s] Game will be paused on next round start by {green}Security {default}team request", CHAT_PFX);
		}else if(g_team_pause_req[INSURGENTS]){
			CPrintToChatAll("[%s] Game will be paused on next round start by {green}Insurgents {default}team request", CHAT_PFX);
		}
	}
	return Plugin_Continue;
}


public MPINS_OnHelpCalled(client){
	PrintToConsole(client, " p                Pause game");
	PrintToConsole(client, " up               Unpause game");
}
public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	if(new_status == MPINS_MatchStatus:LIVE){
		pause_reset();
	}else if(new_status == MPINS_MatchStatus:WAITING){
		pause_reset();
	}
	return Plugin_Continue;
}
public Action:MPINS_OnAllTeamsReady(const String:rdy_for[]){
	PrintToServer("[PAUSE] OnAllTeamsReady");
	if(StrEqual(rdy_for, WaitingForUnpause)){
		unpause();
		//return Plugin_Handled;
	}
	return Plugin_Continue;
}



public pause_SetState(PAUSE_STATE:new_state){
	if(g_paused == new_state)
		return;
	g_paused = new_state;
	if(new_state == PAUSE_STATE:NOT_PAUSED) pause_OnNotPaused();
	else if(new_state == PAUSE_STATE:PAUSED) pause_OnPaused();
	else if(new_state == PAUSE_STATE:UNPAUSING) pause_OnUnpause();
}

public pause_OnNotPaused(){
	InsertServerCommand("unpause");
	ServerExecute();
}

public pause_OnPaused(){
	InsertServerCommand("setpause");
	ServerExecute();
}
public pause_OnUnpause(){
	MPINS_Native_UnsetWaitForReadiness(WaitingForUnpause);
	g_time_limit_force = g_timer_force_unpause;
	CreateTimer(1.0, unpause_stage_1);
}









public cmd_fn_pause_pause(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(!check_pause_request(client, team))
		return;
	if(CVAR_matchplugin_pause_delay_nextround.BoolValue){
		if(!g_team_pause_req[team]){
			CPrintToChatAll("[%s] {green}%N {default}was requested game pause. Game will be paused in a next round.", CHAT_PFX, client);
			g_team_pause_req[team] = true;
		}
		return;
	}
	pause_request(client);
}
public cmd_fn_pause_unpause(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	new String:rdy_for[64];
	MPINS_Native_GetCurrentReadinessFor(rdy_for, sizeof(rdy_for));
	if(!StrEqual(rdy_for, WaitingForUnpause) || g_paused != PAUSE_STATE:PAUSED)
		return;
	if(m_args.Length < 3){
		MPINS_Native_SetTeamReadiness(team, true);
	}else{
		new String:arg2[32];
		m_args.GetString(2, arg2, sizeof(arg2));
		if(StrEqual("f", arg2) ||
		   StrEqual("force", arg2)){
			CPrintToChatAll("[%s] {green}%N {default}was requested force unpause", CHAT_PFX, client);
			unpause();
		}
	}
}
public cmd_fn_pause_cancel(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(g_team_pause_req[team]){
		CPrintToChatAll("[%s] {green}%N {default}has canceled game pause.", CHAT_PFX, client);
 		g_team_pause_req[team] = false;
	}
}






public pause(TEAM:team){
	g_pauser = team;
	MPINS_Native_SetWaitForReadiness(WaitingForUnpause, WaitingForUnpauseDescr);
	pause_SetState(PAUSED);
}

public unpause(){
	if(g_unpause_timer)
		KillTimer(g_unpause_timer);
	g_pauser = TEAM:NONE;
	MPINS_Native_UnsetWaitForReadiness(WaitingForUnpause);
	pause_SetState(UNPAUSING);
}
public pause_reset(){
	if(g_unpause_timer)
		KillTimer(g_unpause_timer);
	g_pauser = TEAM:NONE;
	g_time_limit_force = g_timer_force_unpause;
	for(new TEAM:t; t<TEAM;t++){
		g_team_pause_req[t] = false;
	}
	for(new TEAM:t; t<TEAM;t++){
		g_team_limits[t] = CVAR_matchplugin_pause_team_limit.IntValue;
	}
	for(new TEAM:t; t<TEAM;t++){
		g_time_limits[t] = CVAR_matchplugin_pause_time_limit.IntValue;
	}
	MPINS_Native_UnsetWaitForReadiness(WaitingForUnpause);
	pause_SetState(NOT_PAUSED);
}


bool:check_pause_request(client, TEAM:team){
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	if(g_paused != PAUSE_STATE:NOT_PAUSED){
		if(client)
			PrintToChat(client, "[%s] Game not paused", CHAT_PFX);
		return false;
	}
	if(match_status != LIVE){
		if(client)
			PrintToChat(client, "[%s] Match not started yet", CHAT_PFX);
		return false;
	}
	if(!(g_team_limits[team] < 0 || g_team_limits[team] > 0)){     // Out of pause requests
		if(client)
			CPrintToChat(client, "[%s] Your team has {green}%d/%d {default}pause request left",
						 CHAT_PFX, g_team_limits[team], CVAR_matchplugin_pause_team_limit.IntValue);
		return false;
	}
	if(!((g_time_limits[team] < 0 || g_time_limits[team] > g_timer_min))){ // Out of pause time; Min pause allowed time, no sense to set it lower
		if(client)
			CPrintToChat(client, "[%s] Allowed pause seconds already was spent",
						 CHAT_PFX);
		return false;
	}
	return true;
}

pause_request(client=0, TEAM:team=TEAM:NONE){
	if(g_paused != PAUSE_STATE:NOT_PAUSED)
		return;
	if(client)
		team = TEAM:GetClientTeam(client);
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	decl String:team_n[32];
	InsGetTeamName(team, team_n, sizeof(team_n));
	if(!check_pause_request(client, team))
		return;
	if(client)	CPrintToChatAll("[%s] {green}%N {default}was requested game pause", CHAT_PFX, client);
	else		CPrintToChatAll("[%s] {green}%s {default}team was requested game pause.", CHAT_PFX, team_n);
	if(g_team_limits[team] > 0)
		CPrintToChatAll("[%s] {green}%s {default}team has {green}%d/%d {default}pause requests",
						CHAT_PFX, team_n, g_team_limits[team], CVAR_matchplugin_pause_team_limit.IntValue);
	if(g_team_limits[team] > 0)
		g_team_limits[team]--;
	if(g_time_limits[team] > 0){
		CPrintToChatAll("[%s] {green}%s {default}team has {green}%d {default}pause seconds left",
						CHAT_PFX, team_n, g_time_limits[team], CVAR_matchplugin_pause_time_limit.IntValue);
		pause(team);
		g_unpause_timer = CreateTimer(1.0, Timer_Unpause, 0);
		return;
	}
	pause(team);
}


public Action:Timer_Unpause(Handle:timer, time_passed){
	//PrintToServer("TIMER FIRED: %d::%d::%d", time_passed, g_time_limits[g_pauser], g_time_limit_force);
	if(g_paused == PAUSE_STATE:PAUSED){
		if(MPINS_Native_GetTeamReadiness(g_pauser)){ // If pauser team already ready //FIXME: can be abused to momental autounpause
			if(g_time_limit_force <= 0){
				g_unpause_timer = INVALID_HANDLE;
				CPrintToChatAll("[%s] Game will be automaticly unpaused", CHAT_PFX);
				unpause();
				return;
			}else{
				CPrintToChatAll("[%s] Game will be automaticly unpaused in {green}%d {default}seconds",
								CHAT_PFX, g_time_limit_force);
			}
			g_time_limit_force -= time_passed;
			g_unpause_timer = CreateTimer(float(g_timer_prec), Timer_Unpause, g_timer_prec);
			return;
		}
		new time_left;
		g_time_limits[g_pauser] -= time_passed;
		if(g_time_limits[g_pauser] > g_timer_min){
			time_left = (g_time_limits[g_pauser] - g_timer_min);
			if(time_left < g_timer_prec){
				g_unpause_timer = CreateTimer(float(time_left), Timer_Unpause, time_left);
				return;
			}else{
				g_unpause_timer = CreateTimer(float(g_timer_prec), Timer_Unpause, g_timer_prec);
				return;
			}
		}else{
			if(g_time_limits[g_pauser] > 1)
				CPrintToChatAll("[%s] Game will be automaticly unpaused in {green}%d {default}seconds",
								CHAT_PFX, g_time_limits[g_pauser]);
			time_left = g_time_limits[g_pauser] - g_timer_prec;
			if(time_left > 1){
				g_unpause_timer = CreateTimer(float(g_timer_prec), Timer_Unpause, g_timer_prec);
				return;
			}else{
				time_left = g_time_limits[g_pauser];
				if(time_left > 1){
					g_unpause_timer = CreateTimer(float(time_left), Timer_Unpause, time_left);
				}else{
					g_unpause_timer = INVALID_HANDLE;
					CPrintToChatAll("[%s] Game will be automaticly unpaused", CHAT_PFX);
					unpause();
					return;
				}
			}
		}
	}
	g_unpause_timer = INVALID_HANDLE;
}






public Action:unpause_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","-----> UNPAUSING <-----");
	CPrintToChatAll("{green}%s","-----> 5 <-----");
	CreateTimer(1.0, unpause_stage_2);
}
public Action:unpause_stage_2(Handle:timer){
	CPrintToChatAll("{green}%s","----> 4 <----");
	CreateTimer(1.0, unpause_stage_3);
}
public Action:unpause_stage_3(Handle:timer){
	CPrintToChatAll("{green}%s","---> 3 <---");
	CreateTimer(1.0, unpause_stage_4);
}
public Action:unpause_stage_4(Handle:timer){
	CPrintToChatAll("{green}%s","--> 2 <--");
	CreateTimer(1.0, unpause_stage_5);
}
public Action:unpause_stage_5(Handle:timer){
	CPrintToChatAll("{green}%s","-> 1 <-");
	CreateTimer(1.0, unpause_stage_6);
}
public Action:unpause_stage_6(Handle:timer){
	CPrintToChatAll("{green}%s","-> GO! <-");
	pause_SetState(NOT_PAUSED);
}
