#include <matchplugin_ins>
#include <colors>

public Plugin:myinfo ={
	name = "Match Plugin Pistol Round",
	author = "Aphex <steamfor@gmail.com>",
	description = "Pistol Round for Insurgency Match Plugin",
	version = "0.9.2",
	url = "http://www.sourcemod.net/"
};


new const String:WaitingForUnpause[] = "pause_unpause";
new const String:WaitingForUnpauseDescr[] = "game unpause";

enum PAUSE_STATE{
	NONE,
	NOT_PAUSED,
	PAUSED,
	UNPAUSING
};
new PAUSE_STATE:g_paused = NOT_PAUSED;


public void OnPluginStart(){

}


public void OnAllPluginsLoaded(){
	new Handle:ch = GetMyHandle();
	MPINS_Native_RegCmd("p",				"cmd_fn_pause_pause", ch);
	MPINS_Native_RegCmd("pause",			"cmd_fn_pause_pause", ch);
}

public OnClientDisconnect(client){
	//if(!IsFakeClient(client))
	if(!IsClientInGame(client))
		return;
	new MPINS_MatchStatus:match_status;
	MPINS_Native_GetMatchStatus(match_status);
	if(match_status == LIVE && g_paused == NOT_PAUSED){
		CPrintToChatAll("[%s] Autopausing game due player disconnecting", CHAT_PFX);
		CPrintToChatAll("[%s] In order to reconnect to server the game has to be unpaused", CHAT_PFX);
		pause_SetState(PAUSED);
		MPINS_Native_SetWaitForReadiness(WaitingForUnpause, WaitingForUnpauseDescr);
		return;
	}
}

//IMPLEMENTME
/*
public Action:GameEvents_player_team(Handle:event, const String:name[], bool:dontBroadcast){
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new TEAM:oldteam = TEAM:GetEventInt(event, "oldteam"); 
	new TEAM:team = TEAM:GetEventInt(event, "team");
	if(oldteam && team != oldteam){
		if(g_match_status == LIVE){
			if(g_paused == PAUSE_STATE:NOT_PAUSED){
				PrintToChatAll("[%s] Auto pausing game due player team change", CHAT_PFX);
				pause_game();
			}
		}
	}
}
*/

public MPINS_OnHelpCalled(client){
	PrintToConsole(client, " p				 Pause/unpause game");
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
	//PrintToServer("[%s] Not paused", CHAT_PFX);
	//PrintToChatAll("[%s] Not paused", CHAT_PFX);
	InsertServerCommand("unpause");
	ServerExecute();
}

public pause_OnPaused(){
	//PrintToServer("[%s] Paused", CHAT_PFX);
	//PrintToChatAll("[%s] Paused", CHAT_PFX);
	InsertServerCommand("pause");
	ServerExecute();
}
public pause_OnUnpause(){
	//PrintToServer("[%s] Unpaused", CHAT_PFX);
	//PrintToChatAll("[%s] Unpaused", CHAT_PFX);
	unpause();
}


public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	if(new_status == MPINS_MatchStatus:WAITING){
		pause_SetState(NOT_PAUSED);
	}
	return Plugin_Continue;
}



public cmd_fn_pause_pause(client, ArrayList:m_args){
	if(g_paused == PAUSE_STATE:UNPAUSING)
		return;
	if(g_paused == PAUSE_STATE:NOT_PAUSED){
		new MPINS_MatchStatus:match_status;
		MPINS_Native_GetMatchStatus(match_status);
		if(match_status == LIVE){
			new String:cname[50];
			GetClientName(client, cname, sizeof(cname));
			CPrintToChatAll("[%s] {green}%s {default}was requested game pause", CHAT_PFX, cname);
			MPINS_Native_SetWaitForReadiness(WaitingForUnpause, WaitingForUnpauseDescr);
			pause_SetState(PAUSED);
		}else{
			PrintToChat(client, "[%s] Match not started yet.", CHAT_PFX);
		}
	}else{
		if(m_args.Length > 2){
			new String:arg2[32];
			m_args.GetString(2, arg2, sizeof(arg2));
			if(StrEqual("f", arg2) ||
			   StrEqual("force", arg2)){
				new String:cname[50];
				GetClientName(client, cname, sizeof(cname));
				CPrintToChatAll("[%s] {green}%s {default}was requested force unpause", CHAT_PFX, cname);
				MPINS_Native_UnsetWaitForReadiness(WaitingForUnpause);
				pause_SetState(UNPAUSING);
			}
		}
	}
}

public Action:MPINS_OnAllTeamsReady(const String:rdy_for[]){
	PrintToServer("[PAUSE] OnAllTeamsReady");
	if(StrEqual(rdy_for, WaitingForUnpause)){
		pause_SetState(UNPAUSING);
		//return Plugin_Handled;
	}
	return Plugin_Continue;
}



public unpause(){
	CPrintToChatAll("{green}%s","-----> UNPAUSING <-----");
	CreateTimer(1.0, unpause_stage_1);
}

public Action:unpause_stage_1(Handle:timer){
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
