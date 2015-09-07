#include <matchplugin_ins>
#include <colors>

public Plugin:myinfo ={
	name = "Match Plugin Pistol Round",
	author = "Aphex <steamfor@gmail.com>",
	description = "Pistol Round for Insurgency Match Plugin",
	version = "0.9.0",
	url = "http://www.sourcemod.net/"
};



enum PAUSE_STATE{
	NONE,
	NOT_PAUSED,
	PAUSED,
	UNPAUSING
};
new PAUSE_STATE:g_paused = NOT_PAUSED;

new MPINS_MatchStatus:g_match_status 
//new bool:g_round_end = true;


public void OnPluginStart(){
	//HookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	//HookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
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
	if(g_match_status == STARTING ||
	   g_match_status == LIVE_ON_RESTART ||
	   g_match_status == LIVE
	   ){
		CPrintToChatAll("[%s] Autopausing game due player disconnecting", chat_pfx);
		CPrintToChatAll("[%s] In order to reconnect to server the game has to be unpaused", chat_pfx);
		pause_SetState(PAUSE_STATE:PAUSED);
		MPINS_Native_SetWaitForReadiness("pause_unpause", "game unpause");
		return;
	}
}




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
	//PrintToServer("[%s] Not paused", chat_pfx);
	//PrintToChatAll("[%s] Not paused", chat_pfx);
	InsertServerCommand("unpause");
	ServerExecute();
}

public pause_OnPaused(){
	//PrintToServer("[%s] Paused", chat_pfx);
	//PrintToChatAll("[%s] Paused", chat_pfx);
	InsertServerCommand("pause");
	ServerExecute();
}
public pause_OnUnpause(){
	//PrintToServer("[%s] Unpaused", chat_pfx);
	//PrintToChatAll("[%s] Unpaused", chat_pfx);
	CreateTimer(1.0, unpause_stage_1);
}

/*
  public GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
  g_round_end = false;
  PrintToChatAll("[PR] RoundStart");
  PrintToServer("[PR] RoundStart");
  if(g_pr_status == MPINS_PR_Status:LIVE_ON_RESTART){
  change_status(MPINS_PR_Status:LIVE);
  }
  }
  public GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
  g_round_end = true;
  PrintToChatAll("[PR] RoundEnd");
  PrintToServer("[PR] RoundEnd");
  if(g_pr_status == MPINS_PR_Status:LIVE){
  change_status(MPINS_PR_Status:ENDED);
  }
  }
*/



public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	g_match_status = new_status;
	if(new_status == MPINS_MatchStatus:WAITING){
		pause_SetState(PAUSE_STATE:NOT_PAUSED);
	}
	return Plugin_Continue;
}



public cmd_fn_pause_pause(client, ArrayList:m_args){
	if(g_paused == PAUSE_STATE:UNPAUSING)
		return;
	if(g_paused == PAUSE_STATE:NOT_PAUSED){
		if(g_match_status == LIVE){
			new String:cname[50];
			GetClientName(client, cname, sizeof(cname));
			CPrintToChatAll("[%s] {green}%s {default}was requested game pause", chat_pfx, cname);
			//CPrintToChatAll("[%s] {green}%s ready {default}when your team will be ready", chat_pfx, g_chat_command_prefix);
			MPINS_Native_SetWaitForReadiness("pause_unpause", "game unpause");
			pause_SetState(PAUSE_STATE:PAUSED);
		}else{
			PrintToChat(client, "[%s] Match not started yet.", chat_pfx);
		}
	}else{
		if(m_args.Length > 2){
			new String:arg2[32];
			m_args.GetString(2, arg2, sizeof(arg2));
			if(StrEqual("f", arg2) ||
			   StrEqual("force", arg2)){
				new String:cname[50];
				GetClientName(client, cname, sizeof(cname));
				CPrintToChatAll("[%s] {green}%s {default}was requested force unpause", chat_pfx, cname);
				pause_SetState(PAUSE_STATE:UNPAUSING);
			}
		}
	}
}

public Action:MPINS_OnAllTeamsReady(const String:rdy_for[]){
	if(StrEqual(rdy_for, "pause_unpause")){
		pause_SetState(PAUSE_STATE:UNPAUSING);
		//return Plugin_Handled;
	}
	return Plugin_Continue;
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
	pause_SetState(PAUSE_STATE:NOT_PAUSED);
}
