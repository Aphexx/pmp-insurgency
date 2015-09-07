#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <colors>
#include <sdkhooks>
#include <textparse>

#include <matchplugin_ins>

public Plugin:myinfo ={
	name = "Match Plugin Insurgency",
	author = "Aphex <steamfor@gmail.com>",
	description = "Match Server Plugin for Insurgency",
	version = "2.0.2a",
	url = "http://www.sourcemod.net/"
};



new MPINS_MatchStatus:g_match_status = NONE;
new MPINS_MatchStatus:g_new_match_status;
new Handle:FWD_OnMatchStatusChange;
new Handle:FWD_OnChatCmd;
new Handle:FWD_OnHelpCalled;
new Handle:FWD_OnTeamReady;
new Handle:FWD_OnTeamUnready;
new Handle:FWD_OnAllTeamsReady;


new Menu:g_voting_menu;



new g_team_player_cnt[TEAM];
new g_player_cnt;

new String:g_chat_command_prefix[32] = "#.#";
new Handle:g_maplist;


new StringMap:g_cmds;		//"cmd_alias" -> "fn_name"
new StringMap:g_cmds_fn;	//"fn_name" -> "plugin_handler"
//new StringMap:g_cmds_help;	//"cmd" -> "help info"'
new StringMap:g_votes;
new StringMap:g_votes_fn;

new bool:g_is_waiting_rdy;
new bool:g_teams_rdy[TEAM];
new String:g_rdy_for[64];
new String:g_rdy_descr[256];

new StringMap:g_configs;
new String:g_curcfg[64] = "default";
new bool:g_SMC_configs_sec = false;

//new bool:g_round_end = false;

//new String:g_hostname[64];

new Handle:g_CVAR_pmp_cmd_prefix;
new Handle:g_CVAR_pmp_welcome;
//new Handle:g_CVAR_pmp_hostname_tail_status;
//new Handle:g_CVAR_pmp_hostname;
new Handle:g_CVAR_pmp_disable_kill;





public OnPluginStart(){
	PrintToServer("		 Initing matchplugin!");
	InitVars();
	InitCVARs();
	InitCMDs();
	InitHooks();

	AutoExecConfig(true);
	load_config_file("configs/match_plugin.txt");
	exec_config(g_curcfg);
}
public OnPluginEnd(){
	RemoveCVARs();
	RemoveCMDs();
	RemoveHooks();
}
public OnConfigsExecuted(){
	////new Handle:cv_hostname = FindConVar("hostname");
	////GetConVarString(cv_hostname, g_hostname, sizeof(g_hostname));

	//GetConVarString(g_CVAR_pmp_hostname, g_hostname, sizeof(g_hostname));

	new maplist_serial = -1;
	ReadMapList(g_maplist, maplist_serial, "default", MAPLIST_FLAG_CLEARARRAY);

	//change_status(MATCH_STATUS:WAITING);
}

public OnMapStart(){
	//SetMatchStatus
	MPINS_Native_SetMatchStatus(MPINS_MatchStatus:WAITING);
}

public OnClientDisconnect(client){
	//if(!IsFakeClient(client))
	g_player_cnt--;
	if(!IsClientInGame(client))
		return;

	new TEAM:team = TEAM:GetClientTeam(client);
	g_team_player_cnt[team]--;
	if(g_team_player_cnt[team]<1){
		if(team != TEAM:SPECTATORS){
			new String:rdy_for[64];
			MPINS_Native_GetCurrentReadinessFor(rdy_for, sizeof(rdy_for));
			if(StrEqual(rdy_for, "match_start")){
				MPINS_Native_SetTeamReadiness(team, false);
			}
		}
	}
	/* //MOVEME
	   if(g_player_cnt < 1){
	   map_advance(); //Change map/reload server configs after last player disconnected
	   }
	*/
	/*
	if(g_player_cnt < 2){ // Stop match if only one player left
		if(g_match_status != MPINS_MatchStatus:WAITING &&
		   g_match_status != MPINS_MatchStatus:STOPING &&
		   g_match_status != MPINS_MatchStatus:ENDED
		   ){
			MPINS_Native_SetMatchStatus(MPINS_MatchStatus:STOPING);
			return;
		}
	}
	*/
}



public InitVars(){
	g_maplist = CreateArray(32);
	g_configs = new StringMap();

	g_cmds = new StringMap();
	g_cmds_fn = new StringMap();
	//g_cmds_help = new StringMap();
	g_votes = new StringMap();
	g_votes_fn = new StringMap();

	new Handle:ch = GetMyHandle();

	MPINS_Native_RegCmd("help",				"cmd_fn_help", ch);
	MPINS_Native_RegCmd("h",				"cmd_fn_help", ch);
	MPINS_Native_RegCmd("start",			"cmd_fn_start", ch);
	MPINS_Native_RegCmd("e",				"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("exec",				"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("execcfg",			"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("r",				"cmd_fn_ready", ch);
	MPINS_Native_RegCmd("ready",			"cmd_fn_ready", ch);
	MPINS_Native_RegCmd("nr",				"cmd_fn_notready", ch);
	MPINS_Native_RegCmd("notready",			"cmd_fn_notready", ch);
	MPINS_Native_RegCmd("stop",				"cmd_fn_stop", ch);
	MPINS_Native_RegCmd("cm",				"cmd_fn_changemap", ch);
	MPINS_Native_RegCmd("map",				"cmd_fn_changemap", ch);
	MPINS_Native_RegCmd("nm",				"cmd_fn_nextmap", ch);
	MPINS_Native_RegCmd("nextmap",			"cmd_fn_nextmap", ch);
	MPINS_Native_RegCmd("rr",				"cmd_fn_restartround", ch);
	MPINS_Native_RegCmd("restartround",		"cmd_fn_restartround", ch);
	MPINS_Native_RegCmd("rg",				"cmd_fn_restartgame", ch);
	MPINS_Native_RegCmd("restartgame",		"cmd_fn_restartgame", ch);
	MPINS_Native_RegCmd("st",				"cmd_fn_switchteams", ch);
	MPINS_Native_RegCmd("switchteams",		"cmd_fn_switchteams", ch);
	MPINS_Native_RegCmd("sp",				"cmd_fn_showpassword", ch);
	MPINS_Native_RegCmd("showpassword",		"cmd_fn_showpassword", ch);
	MPINS_Native_RegCmd("status",			"cmd_fn_status", ch);
	MPINS_Native_RegCmd("lc",				"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("listcfg",			"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("listconfig",		"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("ks",				"cmd_fn_kickspectators", ch);
	MPINS_Native_RegCmd("kickspectators",	"cmd_fn_kickspectators", ch);


	MPINS_Native_RegVote("vote_test", "VoteHandler_test", ch);
}

public InitCVARs(){
	g_CVAR_pmp_cmd_prefix =				CreateConVar("sm_pmp_cmd_prefix",			g_chat_command_prefix,	"Chat command prefix");
	g_CVAR_pmp_welcome =				CreateConVar("sm_pmp_welcome",				"1",					"Enable player welcome message");
	//g_CVAR_pmp_hostname_tail_status =	CreateConVar("sm_pmp_hostname_tail_status",	"0",					"Enables displaying server status at hostname tail");
	//g_CVAR_pmp_hostname =				CreateConVar("sm_pmp_hostname",				"Your hostname | ",		"Dynamic hostname");
	g_CVAR_pmp_disable_kill =			CreateConVar("sm_pmp_disable_kill",			"1",					"Disable 'kill' cmd for players");
	HookConVarChange(g_CVAR_pmp_cmd_prefix,		OnChange_CVAR_pmp_cmd_prefix);
	HookConVarChange(g_CVAR_pmp_disable_kill,	OnChange_CVAR_pmp_disable_kill);
}
public RemoveCVARs(){
	UnhookConVarChange(g_CVAR_pmp_cmd_prefix, OnChange_CVAR_pmp_cmd_prefix);
	UnhookConVarChange(g_CVAR_pmp_disable_kill,	OnChange_CVAR_pmp_disable_kill);
}

public InitCMDs(){
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
}
public RemoveCMDs(){
	SetCommandFlags("kill", GetCommandFlags("kill") & ~(FCVAR_CHEAT));
}

public InitHooks(){
	HookEvent("game_start", GameEvents_GameStart);
	HookEvent("game_end", GameEvents_GameEnd);
	HookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", GameEvents_player_team);
}
public RemoveHooks(){
	UnhookEvent("game_start", GameEvents_GameStart);
	UnhookEvent("game_end", GameEvents_GameEnd);
	UnhookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("player_team", GameEvents_player_team);
}




/*
 * CVARS Hooks
 */
public OnChange_CVAR_pmp_cmd_prefix(Handle:convar, const String:oldValue[], const String:newValue[]){
	strcopy(g_chat_command_prefix, sizeof(g_chat_command_prefix), newValue);
	SetConVarString(convar, g_chat_command_prefix);
}
public OnChange_CVAR_pmp_disable_kill(Handle:convar, const String:oldValue[], const String:newValue[]){
	new disable_kill = GetConVarBool(convar);
	if(disable_kill)
		SetCommandFlags("kill", GetCommandFlags("kill") | FCVAR_CHEAT);
	else
		SetCommandFlags("kill", GetCommandFlags("kill") & ~(FCVAR_CHEAT));
}





/*
 * Game Events
 */
public Action:GameEvents_GameStart(Handle:event, const String:name[], bool:dontBroadcast){
	return Plugin_Continue;
}
public Action:GameEvents_GameEnd(Handle:event, const String:name[], bool:dontBroadcast){
	MPINS_Native_SetMatchStatus(MPINS_MatchStatus:ENDED);
	return Plugin_Continue;
}
public GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	//g_round_end = false;
	if(g_match_status == MPINS_MatchStatus:LIVE_ON_RESTART){
		MPINS_Native_SetMatchStatus(MPINS_MatchStatus:LIVE);
	}
}
public GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	//g_round_end = true;
}
public Action:GameEvents_player_team(Handle:event, const String:name[], bool:dontBroadcast){
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new TEAM:oldteam = TEAM:GetEventInt(event, "oldteam"); 
	new TEAM:team = TEAM:GetEventInt(event, "team");


	g_team_player_cnt[team]++;
	if(oldteam){
		g_team_player_cnt[oldteam]--;
		if(g_team_player_cnt[oldteam]<1){
			if(oldteam != TEAM:SPECTATORS){
				new String:rdy_for[64];
				MPINS_Native_GetCurrentReadinessFor(rdy_for, sizeof(rdy_for));
				if(StrEqual(rdy_for, "match_start")){
					MPINS_Native_SetTeamReadiness(oldteam, false);
				}
			}
		}
	}
	//FIXME
	/*
	  if(oldteam && team != oldteam){
	  if(g_match_status == LIVE){
	  if(g_paused == PAUSE_STATE:NOT_PAUSED){
	  PrintToChatAll("[%s] Auto pausing game due player team change", chat_pfx);
	  pause_game();
	  }
	  }
	  }
	*/
	return Plugin_Continue;
}







public Action:map_advance(){
	//if(g_player_cnt > 0)
	//	return;
	new String:map[64];
	new Handle:nextmap = FindConVar("nextlevel");
	if(nextmap != INVALID_HANDLE){
		GetConVarString(nextmap, map, sizeof(map));
		if(!StrEqual(map, "") && IsMapValid(map)){
			ServerCommand("changelevel \"%s\"", map);
		}else{
			GetCurrentMap(map, sizeof(map));
		}
	}else{
		GetCurrentMap(map, sizeof(map));
	}
	ServerCommand("changelevel \"%s\"", map);
	ServerExecute();
}




public Action:Command_Say(client, args){
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);

	//new String:m_args[6][512];
	//new ArrayList:m_args = new ArrayList();
	//new m_args_cnt;
	//m_args_cnt = ExplodeString(message, " ", m_args, sizeof(m_args), sizeof(m_args[]), true);	 //TODO:replace by BreakString

	//new Action:res = MPINS_Native_OnChatCmd(client, m_args_cnt, m_args);
	new Action:act;
	MPINS_Native_ChatCmd(client, message, act);
	if(act == Plugin_Continue)
		return Plugin_Continue;
	return Plugin_Handled;
	/*
	if(g_paused == PAUSE_STATE:PAUSED || g_paused == PAUSE_STATE:UNPAUSING){ //TODO: Add team chat support
		new String:cname[50];
		GetClientName(client, cname, sizeof(cname));
		if(ti == TEAM_SECURITY)
			CPrintToChatAll("[%s] {red}%s: {default}%s", chat_pfx, cname, message);
		else if(ti == TEAM_INSURGENTS)
			CPrintToChatAll("[%s] {blue}%s: {default}%s", chat_pfx,	 cname, message);
		return Plugin_Handled;
	}
	*/
	//return Plugin_Continue;
}


public Action:MPINS_OnChatCmd(client, const String:message[]){
	decl String:args[6][64];
	new args_cnt;
	new i,si;
	for(; args_cnt<6;args_cnt++){
		si = BreakString(message[i], args[args_cnt], sizeof(args[]));
		if(si == -1) break;
		i += si;
	}
	if(strcmp(args[0], g_chat_command_prefix) != 0){
		return Plugin_Continue;
	}
	new ArrayList:largs = new ArrayList(64);
	for(i=0;i<=args_cnt;i++){
		largs.PushString(args[i]);
	}
	new ti = GetClientTeam(client);
	if(args_cnt < 1){
		cmd_fn_help(client, largs);
		return Plugin_Handled;
	}
	if(ti == TEAM_SPECTATORS){ // FIXME
		return Plugin_Continue;
	}

	new String:buf_fn_name[64];
	if(g_cmds.GetString(args[1], buf_fn_name, sizeof(buf_fn_name))){
		new Handle:buf_fn_plugin;
		if(g_cmds_fn.GetValue(buf_fn_name, buf_fn_plugin)){
			new Function:cmd_fn = Function:GetFunctionByName(buf_fn_plugin, buf_fn_name);
			Call_StartFunction(buf_fn_plugin, cmd_fn);
			Call_PushCell(client);
			Call_PushCell(largs);
			Call_Finish();
		}else{
			PrintToChat(client, "[%s] ERROR", chat_pfx);
		}
	}else{
		PrintToChat(client, "[%s] Unknown command\nTry \"%s help\" for command list.", chat_pfx, g_chat_command_prefix);
	}
	delete largs;
	return Plugin_Handled;
}




public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	PrintToChatAll("[MP] >>> %d -> %d", old_status, new_status);
	PrintToServer("[MP] >>> %d -> %d", old_status, new_status);
	if(g_new_match_status != NONE){
		PrintToServer("MP::Changing Status to: %d", g_new_match_status);
		new_status = g_new_match_status;
		g_new_match_status = NONE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public on_match_waiting(){
	exec_config(g_curcfg);

	//g_team_r[TEAM_SECURITY] = false;
	//g_team_r[TEAM_INSURGENTS] = false;
	//g_paused = PAUSE_STATE:NOT_PAUSED;
	//CPrintToChatAll("[%s] {green}Not ready", chat_pfx);
	InsertServerCommand("mp_minteamplayers 50");
	InsertServerCommand("mp_joinwaittime 100000");
	//InsertServerCommand("unpause");
	ServerExecute();
	MPINS_Native_SetWaitForReadiness("match_start", "match start");
}

public on_match_starting(){
	new String:passwd[5];
	new passwd_r = GetRandomInt(1000, 9999);
	IntToString(passwd_r, passwd, sizeof(passwd));

	InsertServerCommand("mp_minteamplayers 1");
	InsertServerCommand("mp_joinwaittime 1");
	InsertServerCommand("sv_password \"%s\"", passwd);
	ServerExecute();

	//change_concat_to_hostname("Match in progress");
	CreateTimer(1.0, start_stage_1);
}

public on_match_live_on_restart(){
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
}


public on_match_live(){
	CPrintToChatAll("{green}%s","=>|GL|--!LIVE!--|HF|<=");
}

public on_match_stoping(){
	CPrintToChatAll("[%s] {green}%s","Stoping match", chat_pfx);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(WAITING);
}

public on_match_ended(){

}























/*
 *	Configs
 */

public load_config_file(String:configFile[]){
	new String:configFilePath[100] = "";
	BuildPath(Path_SM, configFilePath, sizeof(configFilePath), configFile);
	if(!FileExists(configFilePath)){
		create_default_config_file(configFilePath);
		if (!FileExists(configFilePath)){
			SetFailState("Config file '%s' not found.", configFilePath);
		}
	}
	g_configs.Clear();

	new SMCParser:SMC_configs = new SMCParser();
	SMC_configs.OnEnterSection = configs_read_NewSection;
	SMC_configs.OnKeyValue = configs_read_KeyValue;
	SMC_configs.OnLeaveSection = configs_read_EndSection;

	new SMCError:err = SMC_configs.ParseFile(configFilePath);
	if(err != SMCError_Okay){
		char buffer[64];
		if(SMC_configs.GetErrorString(err, buffer, sizeof(buffer))){
			PrintToServer("%s", buffer);
		}else{
			PrintToServer("Fatal parse error");
		}
	}
}
public SMCResult configs_read_NewSection(SMCParser smc, const char[] name, bool opt_quotes){
	if(StrEqual(name, "configs")){
		g_SMC_configs_sec = true;
	}
	return SMCParse_Continue;
}
public SMCResult configs_read_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes){
	if(g_SMC_configs_sec){
		g_configs.SetString(key, value);
	}
	return SMCParse_Continue;
}
public SMCResult configs_read_EndSection(SMCParser smc){
	g_SMC_configs_sec = false;
	return SMCParse_Continue;
}

public create_default_config_file(String:configFilePath[]){
	new Handle:kv_configs = CreateKeyValues("configs");

	KvJumpToKey(kv_configs, "configs", true);
	KvSetString(kv_configs, "default", "server.cfg");

	KvRewind(kv_configs);
	KeyValuesToFile(kv_configs, configFilePath);
	CloseHandle(kv_configs);
}

public exec_config(String:cfgName[]){
	new String:cfgFile[127];

	if(g_configs.GetString(cfgName, cfgFile, sizeof(cfgFile))){
		InsertServerCommand("exec %s", cfgFile);
		ServerExecute();
		return true;
	}
	return false;
}







/*
 * FN
 */
public cmd_fn_start(client, ArrayList:m_args){
	if(g_match_status == WAITING){
		MPINS_Native_SetMatchStatus(STARTING);
		return;
	}
	PrintToChat(client, "[%s] Game already started!", chat_pfx);
}

public cmd_fn_stop(client, ArrayList:m_args){
	if(g_match_status == LIVE){
		MPINS_Native_SetMatchStatus(STOPING);
		return;
	}
	PrintToChat(client, "[%s] Game not running.", chat_pfx);
}

public cmd_fn_changemap(client, ArrayList:m_args){
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", chat_pfx);
		return;
	}
	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
			InsertServerCommand("nextlevel \"%s\"", s_map);
			InsertServerCommand("sm_map \"%s\"", s_map); //FIXME: timeout
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", chat_pfx, s_map);
}

public cmd_fn_nextmap(client, ArrayList:m_args){
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", chat_pfx);
		return;
	}
	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			PrintToChatAll("[%s] Nextmap changed to %s", chat_pfx,	s_map);
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
			InsertServerCommand("nextlevel \"%s\"", s_map);
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", chat_pfx,  s_map);
}

public cmd_fn_restartround(client, ArrayList:m_args){
	PrintToChatAll("[%s] Restarting round...", chat_pfx);
	InsertServerCommand("mp_restartround 5");
	ServerExecute();
}

public cmd_fn_restartgame(client, ArrayList:m_args){
	PrintToChatAll("[%s] Restarting game...", chat_pfx);
	InsertServerCommand("mp_restartgame 5");
	ServerExecute();
}

public cmd_fn_switchteams(client, ArrayList:m_args){
	if(g_match_status == LIVE)
		CPrintToChatAll("[%s] {green}Teams will be switched", chat_pfx);
	else
		CPrintToChatAll("[%s] {green}Teams will be switched on round start", chat_pfx);
	InsertServerCommand("mp_switchteams");
	InsertServerCommand("mp_restartround 1");
	ServerExecute();
}

public cmd_fn_ready(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(team != TEAM:SECURITY && team != TEAM:INSURGENTS)
		return;
	if(MPINS_Native_GetTeamReadiness(team))
		MPINS_Native_SetTeamReadiness(team, false);
	else
		MPINS_Native_SetTeamReadiness(team, true);
	//MPINS_OnTeamReady
	/*
	if(g_team_r[ti])team_set_notready(ti);
	else		team_set_ready(ti);
	check_teams_ready();
	*/
}

public cmd_fn_notready(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(team != TEAM:SECURITY && team != TEAM:INSURGENTS)
		return;
	if(g_teams_rdy[team])
		MPINS_Native_SetTeamReadiness(team, false);
}



public cmd_fn_kickspectators(client, ArrayList:m_args){
	new maxplayers = GetMaxClients();
	for (new x = 1; x <= maxplayers ; x++){
		if(!IsClientInGame(x))
			continue;
		if(GetClientTeam(x) != TEAM_SPECTATORS)
			continue;
		KickClient(x, "Spectators was kicked");
	}
}


public cmd_fn_showpassword(client, ArrayList:m_args){
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];
	GetConVarString(cv_password, password, sizeof(password));
	CPrintToChat(client, "[%s] Password: {green}%s", chat_pfx, password);
}


public cmd_fn_execcfg(client, ArrayList:m_args){
	if(m_args.Length < 3){
		cmd_fn_listcfg(client, m_args);
		return;
	}
	new String:s_cfg[32];
	m_args.GetString(2, s_cfg, sizeof(s_cfg));
	if(exec_config(s_cfg)){
		CPrintToChatAll("[%s] Loaded \"{green}%s{default}\" config", chat_pfx, s_cfg);
		if(!StrEqual(s_cfg, g_curcfg)){ //Advance map if loaded config differs
			strcopy(g_curcfg, sizeof(g_curcfg), s_cfg);
			map_advance();
		}
	}else{
		CPrintToChat(client, "[%s] Config not found: \"{green}%s{default}\"", chat_pfx, s_cfg);
		cmd_fn_listcfg(client, m_args);
	}
}


public cmd_fn_listcfg(client, ArrayList:m_args){
	new StringMapSnapshot:keys = g_configs.Snapshot();
	new String:buf_key[127];
	new String:buf_concat[512];

	for(new i = 0; i < keys.Length; i++){
		keys.GetKey(i, buf_key, sizeof(buf_key));
		if(StrEqual(buf_key, "default")) continue;
		if(i == 0)StrCat(buf_concat, sizeof(buf_concat), " {green}");
		else	StrCat(buf_concat, sizeof(buf_concat), ", {green}");
		StrCat(buf_concat, sizeof(buf_concat), buf_key);
		StrCat(buf_concat, sizeof(buf_concat), "{default}");
	}
	CPrintToChat(client, "[%s] Current config: {green}%s", chat_pfx, g_curcfg);
	CPrintToChat(client, "[%s] Available configs:%s", chat_pfx, buf_concat);
}


public cmd_fn_status(client, ArrayList:m_args){
	print_status(client);
}
public print_status(client){
	new String:match_status[32];
	if(	g_match_status == WAITING)		match_status = "waiting the teams to get ready";
	else if(g_match_status == STARTING)	match_status = "starting match";
	else if(g_match_status == LIVE_ON_RESTART) match_status = "LOR";
	else if(g_match_status == LIVE)		match_status = "LIVE!";
	else if(g_match_status == STOPING)		match_status = "stoping";
	else if(g_match_status == ENDED)		match_status = "eneded";
	CPrintToChat(client, "[%s] Server config: {green}%s", chat_pfx, g_curcfg);
	CPrintToChat(client, "[%s] Game state: {green}%s", chat_pfx,  match_status);
	if(g_is_waiting_rdy){
		CPrintToChat(client, "Waiting readiness signal for %s", g_rdy_descr);
	}
	if(g_teams_rdy[SECURITY])	CPrintToChat(client, "Security: {green}READY");
	else				CPrintToChat(client, "Security: {red}NOT {default}READY");
	if(g_teams_rdy[INSURGENTS])	CPrintToChat(client, "Insurgents: {green}READY");
	else				CPrintToChat(client, "Insurgents: {red}NOT {default}READY");
}


public cmd_fn_help(client, ArrayList:m_args){
	CPrintToChat(client, "[%s] Help info printed into {green}console", chat_pfx);
	PrintToConsole(client, "Usage: %s COMMAND [arguments]", g_chat_command_prefix);
	PrintToConsole(client, "Arguments:");

	Call_StartForward(FWD_OnHelpCalled);
	Call_PushCell(client);
	Call_Finish();
	MPINS_Native_StartVote("vote_test", "Is Aphex awesome?");
}

public MPINS_OnHelpCalled(client){
	PrintToConsole(client, " r				 Marks team as ready/unready. After all teams are ready, executes config, generates server password and starts match");
	PrintToConsole(client, " stop			 Stop match");
	PrintToConsole(client, " e CFGNAME		 Exec config");
	PrintToConsole(client, " lc				 List available configs");
	PrintToConsole(client, " cm MAPNAME		 Changing map to MAPNAME");
	PrintToConsole(client, " nm MAPNAME		 Changing nextmap to MAPNAME");
	PrintToConsole(client, " rg				 Restart game");
	PrintToConsole(client, " rr				 Round restart");
	PrintToConsole(client, " st				 Switch teams");
	PrintToConsole(client, " ks				 Kick spectators");
	PrintToConsole(client, " sp				 Show password");
}


public player_welcome(client){
	if(!GetConVarBool(g_CVAR_pmp_welcome))
		return;
	CPrintToChat(client, "[%s] Welcome on match server", chat_pfx);
	CPrintToChat(client, "[%s] Type {green}%s help {default} for command reference", chat_pfx, g_chat_command_prefix);
	print_status(client);
}



















public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	CreateNative("MPINS_Native_SetMatchStatus", Native_SetMatchStatus);
	//CreateNative("MPINS_Native_GetMatchStatus", Native_GetMatchStatus);
	CreateNative("MPINS_Native_ChatCmd",		Native_ChatCmd);
	CreateNative("MPINS_Native_RegCmd",			Native_RegCmd);
	CreateNative("MPINS_Native_RegVote",		Native_RegVote);
	CreateNative("MPINS_Native_StartVote",		Native_StartVote);

	CreateNative("MPINS_Native_SetWaitForReadiness", Native_SetWaitForReadiness);
	CreateNative("MPINS_Native_GetCurrentReadinessFor", Native_GetCurrentReadinessFor);

	CreateNative("MPINS_Native_GetTeamReadiness", Native_GetTeamReadiness);
	CreateNative("MPINS_Native_SetTeamReadiness", Native_SetTeamReadiness);
	//native bool:MPINS_Native_GetTeamReadiness(team);
	//native MPINS_Native_SetTeamReadiness(team, bool:rdy);


	FWD_OnMatchStatusChange = CreateGlobalForward("MPINS_OnMatchStatusChange", ET_Hook, Param_Cell, Param_CellByRef);
	FWD_OnChatCmd = CreateGlobalForward("MPINS_OnChatCmd", ET_Event, Param_Cell, Param_String);
	FWD_OnHelpCalled = CreateGlobalForward("MPINS_OnHelpCalled", ET_Hook, Param_Cell);

	FWD_OnTeamReady = CreateGlobalForward("MPINS_OnTeamReady", ET_Event, Param_Cell, Param_String);
	FWD_OnTeamUnready = CreateGlobalForward("MPINS_OnTeamUnready", ET_Event, Param_Cell, Param_String);
	FWD_OnAllTeamsReady = CreateGlobalForward("MPINS_OnAllTeamsReady", ET_Event, Param_String);


	RegPluginLibrary("MPINS");
	return APLRes_Success;
}


/*
 * Natives
 */
public Native_RegCmd(Handle:plugin, int numParams){
	new String:cmd_alias[32];
	new String:cmd_fn_name[32];
	new Handle:cmd_plugin;
	GetNativeString(1, cmd_alias, sizeof(cmd_alias));
	GetNativeString(2, cmd_fn_name, sizeof(cmd_fn_name));
	cmd_plugin = GetNativeCell(3);

	g_cmds.SetString(cmd_alias, cmd_fn_name, false);
	g_cmds_fn.SetValue(cmd_fn_name, cmd_plugin, false);
}

public Native_RegVote(Handle:plugin, int numParams){
	new String:vote_name[32];
	new String:vote_fn_name[32];
	new Handle:vote_plugin;
	GetNativeString(1, vote_name, sizeof(vote_name));
	GetNativeString(2, vote_fn_name, sizeof(vote_fn_name));
	vote_plugin = GetNativeCell(3);

	g_votes.SetString(vote_name, vote_fn_name, false);
	g_votes_fn.SetValue(vote_fn_name, vote_plugin, false);
}


public Native_SetMatchStatus(Handle:plugin, int numParams){
	new MPINS_MatchStatus:new_status;
	new_status = GetNativeCell(1);

	PrintToServer("-----------------Changing Status to: '%d'", new_status);
	g_new_match_status = new_status;
	new MPINS_MatchStatus:status;
	PrintToServer("G_match_status: %d", g_match_status);
	if(new_status == g_match_status)
		return false;
	status = MPINS_Native_GetMatchStatus();
	PrintToServer("ActualStatus: %d", status);
	if(new_status != status)
		return false;

	PrintToServer("All ok!");
	g_match_status = status;
	if(status == WAITING)			on_match_waiting();
	else if(status == STARTING)		on_match_starting();
	else if(status == LIVE_ON_RESTART) on_match_live_on_restart();
	else if(status == LIVE)			on_match_live();
	else if(status == STOPING)		on_match_stoping();
	else if(status == ENDED)		on_match_ended();
	return true;
}



public Native_ChatCmd(Handle:plugin, int numParams){
	new client = GetNativeCell(1);
	new String:message[512];
	GetNativeString(2, message, sizeof(message));

	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnChatCmd);
	Call_PushCell(client);
	Call_PushString(message);
	Call_Finish(act);
	SetNativeCellRef(3, act);
}


public MPINS_MatchStatus:MPINS_Native_GetMatchStatus(){
	new MPINS_MatchStatus:old_status = g_match_status;
	new MPINS_MatchStatus:new_status = g_new_match_status;

	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnMatchStatusChange);
	Call_PushCell(old_status);
	Call_PushCellRef(new_status);
	Call_Finish(act);
	if(act == Plugin_Changed || act == Plugin_Stop)
		g_match_status = new_status;
	return g_match_status;
}





/* Voting */
public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2){
	if(action == MenuAction_End){
		delete menu;
		g_voting_menu = null;
	}
}

public void Handler_VoteFinishedGeneric(Menu menu,
										int num_votes,
										int num_clients,
										const int[][] client_info,
										int num_items,
										const int[][] item_info){
	new String:result[64];
	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], result, sizeof(result));

	PrintToChatAll("Winner: %s", result);
	//PrintToChatAll("Akk: %s", item_info[0][VOTEINFO_ITEM_INDEX]);

	/*
	if(num_items > 1){
		float winningvotes = float(item_info[0][VOTEINFO_ITEM_VOTES]);
		float required = num_votes * (FIXME 1 / 100.0);
		if(winningvotes < required){
			PrintToChatAll("Voting Failed");
			return;
		}else{
			PrintToChatAll("Vote succeded");
		}
		}
	*/
	//Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public Native_StartVote(Handle:plugin, int numParams){
	new String:vote_name[32];
	new String:vote_tittle[32];

	GetNativeString(1, vote_name, sizeof(vote_name));
	GetNativeString(2, vote_tittle, sizeof(vote_tittle));


	if(IsVoteInProgress()){
		return;
	}
	new String:buf_fn_name[64];
	if(g_votes.GetString(vote_name, buf_fn_name, sizeof(buf_fn_name))){
		new Handle:buf_fn_plugin;
		if(g_votes_fn.GetValue(buf_fn_name, buf_fn_plugin)){
			new VoteHandler:vote_fn;
			vote_fn = VoteHandler:GetFunctionByName(buf_fn_plugin, buf_fn_name);

			g_voting_menu = new Menu(Handle_VoteMenu);
			g_voting_menu.VoteResultCallback = vote_fn;
			g_voting_menu.SetTitle(vote_tittle);
			g_voting_menu.AddItem("yes", "Yes");
			g_voting_menu.AddItem("no", "No");
			g_voting_menu.ExitButton = false;
			g_voting_menu.DisplayVoteToAll(25);
		}
	}
}


/* Vote Handlers */

public void VoteHandler_test(Menu menu,
							 int num_votes,
							 int num_clients,
							 const int[][] client_info,
							 int num_items,
							 const int[][] item_info){
	//PrintToChatAll("AWESOME IT WORKS");


	/*
	  10
	  8 - yes
	  1 - no

	  num_votes - 9
	  num_clients - 9
	  num_items - 2

	  item_info[0][

	 */
	if(num_votes < 1){
		PrintToChatAll("Voting Failed");
		return;
	}
	new String:winner[64];
	new winner_votes;

	new g_vote_ratio = 100;

	/*
	new client_indexes[num_clients];
	new client_items[num_clients];
	for (new i = 0; i < num_clients; i++){
		client_indexes[i] = client_list[i][VOTEINFO_CLIENT_INDEX];
		client_items[i] = client_list[i][VOTEINFO_CLIENT_ITEM];
	}
	*/

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	winner_votes = item_info[0][VOTEINFO_ITEM_VOTES];



	new winner_ratio = ((winner_votes * 100)/num_votes);
	PrintToChatAll("Vote: [%d/%d] For '%s' voted %d%%", num_clients, num_votes, winner,	 winner_ratio);
	if(winner_ratio >= g_vote_ratio){
		PrintToChatAll("Vote succeded");
	}else{
		PrintToChatAll("Vote failed");
	}
	//Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}
/* ============ */





/* -Readiness */
public Native_SetWaitForReadiness(Handle:plugin, int numParams){
	new String:new_rdy_for[64];
	new String:new_rdy_descr[256];
	GetNativeString(1, new_rdy_for, sizeof(new_rdy_for));
	GetNativeString(2, new_rdy_descr, sizeof(new_rdy_descr));

	if(g_is_waiting_rdy){
		PrintToServer("[%s] Already waiting for team readines", chat_pfx);
		return;
	}
	g_is_waiting_rdy = true;
	g_rdy_for = new_rdy_for;
	g_rdy_descr = new_rdy_descr;

	CPrintToChatAll("[%s] Waiting ready signal");
	CPrintToChatAll("[%s] Type {green}%s ready {default}when your team will be ready for %s", g_chat_command_prefix, g_rdy_descr);
}
public Native_GetCurrentReadinessFor(Handle:plugin, int numParams){
	new str_size = GetNativeCell(2);
	//new String:rdy_for[str_size];
	//GetNativeString(1, rdy_for, sizeof(rdy_for));
	SetNativeString(1, g_rdy_for, str_size+1, false);
}

public Native_GetTeamReadiness(Handle:plugin, int numParams){
	new TEAM:team = TEAM:GetNativeCell(1);
	if(!g_is_waiting_rdy)
		return false;
	if(g_teams_rdy[team])
		return true;
	return false;
}
public Native_SetTeamReadiness(Handle:plugin, int numParams){
	new TEAM:team = TEAM:GetNativeCell(1);
	new bool:new_rdy = GetNativeCell(2);
	if(!g_is_waiting_rdy)
		return;
	if(new_rdy == g_teams_rdy[team])
		return;
	if(new_rdy){
		Call_StartForward(FWD_OnTeamReady);
		Call_PushCell(team);
		Call_PushString(g_rdy_for);
		Call_Finish();
	}else{
		Call_StartForward(FWD_OnTeamUnready);
		Call_PushCell(team);
		Call_PushString(g_rdy_for);
		Call_Finish();
	}
}




public Action:MPINS_OnTeamReady(TEAM:team, const String:rdy_for[]){
	PrintToServer("[%s] Team '%d' ready for '%s'", chat_pfx, team, rdy_for);
	PrintToChatAll("[%s] Team '%d' ready for '%s'", chat_pfx, team, rdy_for);
	g_teams_rdy[team] = true;
	if(g_teams_rdy[team:SECURITY] && g_teams_rdy[team:INSURGENTS]){
		Call_StartForward(FWD_OnAllTeamsReady);
		Call_PushString(g_rdy_for);
		Call_Finish();
	}
	return Plugin_Continue;
}

public Action:MPINS_OnTeamUnready(TEAM:team, const String:rdy_for[]){
	PrintToServer("[%s] Team '%d' NOT ready for '%s'", chat_pfx, team, rdy_for);
	PrintToChatAll("[%s] Team '%d' NOT ready for '%s'", chat_pfx, team, rdy_for);
	g_teams_rdy[team] = false;
	return Plugin_Continue;
}

public Action:MPINS_OnAllTeamsReady(const String:rdy_for[]){
	PrintToServer("[%s] All teams ready for '%s'", chat_pfx, rdy_for);
	PrintToChatAll("[%s] All teams ready for '%s'", chat_pfx, rdy_for);
	g_is_waiting_rdy = false;
	for(new TEAM:i; i<TEAM;i++){
		g_teams_rdy[i] = false;
	}
	if(StrEqual(rdy_for, "match_start")){
		MPINS_Native_SetMatchStatus(STARTING);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


























public Action:start_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","Game Ready!");
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","POV demo started?");
	CPrintToChatAll("{green}%s","=================");
	CreateTimer(7.0, start_stage_2);
}

public Action:start_stage_2(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","-----> 5 <-----");
	CreateTimer(1.0, start_stage_3);
}

public Action:start_stage_3(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","----> 4 <----");
	CreateTimer(1.0, start_stage_4);
}

public Action:start_stage_4(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","---> 3 <---");
	CreateTimer(1.0, start_stage_5);
}

public Action:start_stage_5(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","--> 2 <--");
	CreateTimer(1.0, start_stage_6);
}

public Action:start_stage_6(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","-> 1 <-");
	CreateTimer(1.0, start_stage_7);
}

public Action:start_stage_7(Handle:timer){
	if(g_match_status != STARTING) return;
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];

	CPrintToChatAll("{green}%s","=>--!LIVE ON RESTART!--<=");
	GetConVarString(cv_password, password, sizeof(password));
	CPrintToChatAll("[%s] Password was set to: {green}%s", chat_pfx, password);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(LIVE_ON_RESTART);
}
