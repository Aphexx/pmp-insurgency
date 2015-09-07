#include <sourcemod>



#if defined _matchplugin_ins_included
 #endinput
#endif
#define _matchplugin_ins_included

enum TEAM{
	SPECTATORS=1,
	SECURITY=2,
	INSURGENTS=3
};

#define TEAM_SPECTATORS 1
#define TEAM_SECURITY 2
#define TEAM_INSURGENTS 3
new const String:chat_pfx[] = "MP";



enum MPINS_MatchStatus{
	NONE,
	WAITING,
	STARTING,
	LIVE_ON_RESTART,
	LIVE,
	STOPING,
	ENDED
};

native MPINS_Native_RegCmd(String:cmd_alias[], String:cmd_fn_name[], Handle:cmd_plugin);
native MPINS_Native_RegVote(String:vote_name[], String:vote_fn_name[], Handle:vote_plugin);
//native MPINS_Native_RegReadinessSignal(String:rdy_type_name[], String:rdy_fn_name[], Handle:rdy_plugin);

native MPINS_Native_SetWaitForReadiness(String:rdy_for[], String:rdy_description[]);
native MPINS_Native_GetCurrentReadinessFor(String:rdy_for[], str_size);
native bool:MPINS_Native_GetTeamReadiness(TEAM:team);
native MPINS_Native_SetTeamReadiness(TEAM:team, bool:rdy);
forward Action:MPINS_OnTeamReady(TEAM:team, const String:rdy_for[]);
forward Action:MPINS_OnTeamUnready(TEAM:team, const String:rdy_for[]);
forward Action:MPINS_OnAllTeamsReady(const String:rdy_for[]);



native MPINS_Native_StartVote(const String:vote_name[], const String:vote_tittle[]);


native Action:MPINS_Native_ChatCmd(client, const String:message[], &Action:act);
forward Action:MPINS_Native_OnChatCmd(client, const String:message[]);


native bool:MPINS_Native_SetMatchStatus(MPINS_MatchStatus:new_status);
forward MPINS_MatchStatus:MPINS_Native_GetMatchStatus();


forward MPINS_OnHelpCalled(client);
