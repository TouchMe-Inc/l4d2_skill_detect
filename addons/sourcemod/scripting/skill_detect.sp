#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>


public Plugin myinfo = {
    name        = "SkillDetection",
    author      = "Tabun",
    description = "Detects skeets, levels, highpounces, etc.",
    version     = "build_0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_skill_detect"
}


/*
 * Team.
 */
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/*
 * Infected Class.
 */
#define SI_CLASS_SMOKER         1
#define SI_CLASS_BOOMER         2
#define SI_CLASS_HUNTER         3
#define SI_CLASS_SPITTER        4
#define SI_CLASS_JOCKEY         5
#define SI_CLASS_CHARGER        6
#define SI_CLASS_TANK           8


#define SHOTGUN_BLAST_TIME      0.1
#define HOP_CHECK_TIME          0.1
#define HOPEND_CHECK_TIME       0.1      // after streak end (potentially) detected, to check for realz?
#define SHOVE_TIME              0.05
#define MAX_CHARGE_TIME         12.0     // maximum time to pass before charge checking ends
#define CHARGE_CHECK_TIME       0.25     // check interval for survivors flying from impacts
#define CHARGE_END_CHECK        2.5      // after client hits ground after getting impact-charged: when to check whether it was a death
#define CHARGE_END_RECHECK      3.0      // safeguard wait to recheck on someone getting incapped out of bounds
#define VOMIT_DURATION_TIME     2.25     // how long the boomer vomit stream lasts -- when to check for boom count
#define ROCK_CHECK_TIME         0.34     // how long to wait after rock entity is destroyed before checking for skeet/eat (high to avoid lag issues)
#define CARALARM_MIN_TIME       0.11     // maximum time after touch/shot => alarm to connect the two events (test this for LAG)

#define MIN_DC_TRIGGER_DMG      300      // minimum amount a 'trigger' / drown must do before counted as a death action
#define MIN_DC_FALL_DMG         175      // minimum amount of fall damage counts as death-falling for a deathcharge
#define WEIRD_FLOW_THRESH       900.0    // -9999 seems to be break flow.. but meh
#define MIN_FLOWDROPHEIGHT      350.0    // minimum height a survivor has to have dropped before a WEIRD_FLOW value is treated as a DC spot
#define MIN_DC_RECHECK_DMG      100      // minimum damage from map to have taken on first check, to warrant recheck

#define HOP_ACCEL_THRESH        0.01     // bhop speed increase must be higher than this for it to count as part of a hop streak

#define HITGROUP_HEAD           1

#define DMG_CRUSH               (1 << 0)     // crushed by falling or moving object.
#define DMG_BULLET              (1 << 1)     // shot
#define DMG_SLASH               (1 << 2)     // cut, clawed, stabbed
#define DMG_CLUB                (1 << 7)     // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)    // not quite a bullet. Little, rounder, different.

#define CUT_SHOVED              1            // smoker got shoved
#define CUT_SHOVEDSURV          2            // survivor got shoved
#define CUT_KILL                3            // reason for tongue break (release_type)
#define CUT_SLASH               4            // this is used for others shoving a survivor free too, don't trust .. it involves tongue damage?

#define VICFLG_CARRIED          (1 << 0)     // was the one that the charger carried (not impacted)
#define VICFLG_FALL             (1 << 1)     // flags stored per charge victim, to check for deathchargeroony -- fallen
#define VICFLG_DROWN            (1 << 2)     // drowned
#define VICFLG_HURTLOTS         (1 << 3)     // whether the victim was hurt by 400 dmg+ at once
#define VICFLG_TRIGGER          (1 << 4)     // killed by trigger_hurt
#define VICFLG_AIRDEATH         (1 << 5)     // died before they hit the ground (impact check)
#define VICFLG_KILLEDBYOTHER    (1 << 6)     // if the survivor was killed by an SI other than the charger
#define VICFLG_WEIRDFLOW        (1 << 7)     // when survivors get out of the map and such
#define VICFLG_WEIRDFLOWDONE    (1 << 8)     // checked, don't recheck for this

#define TANK_ROCK               "tank_rock"

// trie values: weapon type
enum WpType {
    WPTYPE_NONE,
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM
};

// trie values: special abilities
enum Ability {
    ABL_HUNTERLUNGE,
    ABL_ROCKTHROW
};

GlobalForward
    g_fwdHeadShot = null,
    g_fwdSkeet = null,
    g_fwdSkeetHurt = null,
    g_fwdSkeetMelee = null,
    g_fwdSkeetSniper = null,
    g_fwdHunterDeadstop = null,
    g_fwdBoomerPop = null,
    g_fwdBoomerPopEarly = null,
    g_fwdChargerLevel = null,
    g_fwdChargerLevelHurt = null,
    g_fwdTongueCut = null,
    g_fwdSmokerSelfClear = null,
    g_fwdRockSkeeted = null,
    g_fwdHunterHighPounce = null,
    g_fwdDeathCharge = null,
    g_fwdSpecialClear = null,
    g_fwdBoomerVomitLanded = null,
    g_fwdBunnyHopStreak = null,
    g_fwdCarAlarmTriggered = null
;

StringMap g_smWeapons;                                           // weapon check
StringMap g_smAbility;                                           // ability check
StringMap g_smRocks;                                             // tank rock tracking

// all SI / pinners
int    g_iSpecialVictim[MAXPLAYERS + 1];                         // current victim (set in traceattack, so we can check on death)
float  g_fSpawnTime    [MAXPLAYERS + 1];                         // time the SI spawned up
float  g_fPinTime      [MAXPLAYERS + 1][2];                      // time the SI pinned a target: 0 = start of pin (tongue pull, charger carry); 1 = carry end / tongue reigned in

// hunters: skeets/pounces
float  g_fHunterTracePouncing [MAXPLAYERS + 1];                  // time when the hunter was still pouncing (in traceattack) -- used to detect pouncing status
int    g_iPounceDamage        [MAXPLAYERS + 1];                  // how much damage on last 'highpounce' done
int    g_iHunterHealth        [MAXPLAYERS + 1];                  // how much health the hunter had the last time it was seen taking damage
float  g_vPouncePosition      [MAXPLAYERS + 1][3];               // position that a hunter pounced from (or charger started his carry)
bool   g_bShotCounted         [MAXPLAYERS + 1][MAXPLAYERS + 1];
int    g_iDmgDealt            [MAXPLAYERS + 1][MAXPLAYERS + 1];
int    g_iShotsDealt          [MAXPLAYERS + 1][MAXPLAYERS + 1];

// deadstops
float  g_fVictimLastShove[MAXPLAYERS + 1][MAXPLAYERS + 1];       // when was the player shoved last by attacker? (to prevent doubles)

// levels / charges
int    g_iChargerHealth  [MAXPLAYERS + 1];                       // how much health the charger had the last time it was seen taking damage
float  g_fChargeTime     [MAXPLAYERS + 1];                       // time the charger's charge last started, or if victim, when impact started
int    g_iChargeVictim   [MAXPLAYERS + 1];                       // who got charged
int    g_iVictimCharger  [MAXPLAYERS + 1];                       // for a victim, by whom they got charge(impacted)
int    g_iVictimFlags    [MAXPLAYERS + 1];                       // flags stored per charge victim: VICFLAGS_
int    g_iVictimMapDmg   [MAXPLAYERS + 1];                       // for a victim, how much the cumulative map damage is so far (trigger hurt / drowning)
float  g_fChargeVictimPos[MAXPLAYERS + 1][3];                    // location of each survivor when it got hit by the charger

// pops
bool   g_bBoomerHitSomebody[MAXPLAYERS + 1];                     // false if boomer didn't puke/exploded on anybody
int    g_iBoomerGotShoved  [MAXPLAYERS + 1];                     // count boomer was shoved at any point
int    g_iBoomerVomitHits  [MAXPLAYERS + 1];                     // how many booms in one vomit so far
int    g_iBoomerKiller     [MAXPLAYERS + 1];
int    g_iBoomerShover     [MAXPLAYERS + 1];
Handle g_hBoomerShoveTimer [MAXPLAYERS + 1];

// smoker clears
bool   g_bSmokerClearCheck  [MAXPLAYERS + 1];                    // [smoker] smoker dies and this is set, it's a self-clear if g_iSmokerVictim is the killer
int    g_iSmokerVictim      [MAXPLAYERS + 1];                    // [smoker] the one that's being pulled
int    g_iSmokerVictimDamage[MAXPLAYERS + 1];                    // [smoker] amount of damage done to a smoker by the one he pulled
bool   g_bSmokerShoved      [MAXPLAYERS + 1];                    // [smoker] set if the victim of a pull manages to shove the smoker

// rocks
int    g_iRocksBeingThrownCount;                                 // so we can do a push/pop type check for who is throwing a created rock
int    g_iTankRockClient[MAXPLAYERS + 1];                        // stores the tank client

// hops
bool   g_bIsHopping     [MAXPLAYERS + 1];                        // currently in a hop streak
bool   g_bHopCheck      [MAXPLAYERS + 1];                        // flag to check whether a hopstreak has ended (if on ground for too long.. ends)
int    g_iHops          [MAXPLAYERS + 1];                        // amount of hops in streak
float  g_fHopTopVelocity[MAXPLAYERS + 1];                        // maximum velocity in hopping streak
float  g_fLastHop       [MAXPLAYERS + 1][3];                     // velocity vector of last jump

// cvars
ConVar g_cvSelfClearThresh;                                     // cvar damage while self-clearing from smokers
ConVar g_cvHunterDPThresh;                                      // cvar damage for hunter highpounce
ConVar g_cvBHopMinInitSpeed;                                    // cvar lower than this and the first jump won't be seen as the start of a streak
ConVar g_cvBHopContSpeed;                                       // cvar speed at which hops are considered succesful even if not speed increase is made

ConVar g_cvMaxPounceDistance;                                   // z_pounce_damage_range_max
ConVar g_cvMinPounceDistance;                                   // z_pounce_damage_range_min
ConVar g_cvMaxPounceDamage;                                     // z_hunter_max_pounce_bonus_damage;


public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax)
{
    g_fwdHeadShot          = CreateGlobalForward("OnHeadShot",          ET_Ignore, Param_Cell, Param_Cell);
    g_fwdBoomerPop         = CreateGlobalForward("OnBoomerPop",         ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float);
    g_fwdBoomerPopEarly    = CreateGlobalForward("OnBoomerPopEarly",    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwdChargerLevel      = CreateGlobalForward("OnChargerLevel",      ET_Ignore, Param_Cell, Param_Cell);
    g_fwdChargerLevelHurt  = CreateGlobalForward("OnChargerLevelHurt",  ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwdHunterDeadstop    = CreateGlobalForward("OnHunterDeadstop",    ET_Ignore, Param_Cell, Param_Cell);
    g_fwdSkeetSniper       = CreateGlobalForward("OnSkeetSniper",       ET_Ignore, Param_Cell, Param_Cell);
    g_fwdSkeetMelee        = CreateGlobalForward("OnSkeetMelee",        ET_Ignore, Param_Cell, Param_Cell);
    g_fwdSkeetHurt         = CreateGlobalForward("OnSkeetHurt",         ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwdSkeet             = CreateGlobalForward("OnSkeet",             ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwdTongueCut         = CreateGlobalForward("OnTongueCut",         ET_Ignore, Param_Cell, Param_Cell);
    g_fwdSmokerSelfClear   = CreateGlobalForward("OnSmokerSelfClear",   ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwdRockSkeeted       = CreateGlobalForward("OnTankRockSkeeted",   ET_Ignore, Param_Cell, Param_Cell);
    g_fwdHunterHighPounce  = CreateGlobalForward("OnHunterHighPounce",  ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell, Param_Cell);
    g_fwdDeathCharge       = CreateGlobalForward("OnDeathCharge",       ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
    g_fwdSpecialClear      = CreateGlobalForward("OnSpecialClear",      ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
    g_fwdBoomerVomitLanded = CreateGlobalForward("OnBoomerVomitLanded", ET_Ignore, Param_Cell, Param_Cell);
    g_fwdBunnyHopStreak    = CreateGlobalForward("OnBunnyHopStreak",    ET_Ignore, Param_Cell, Param_Cell, Param_Float);
    g_fwdCarAlarmTriggered = CreateGlobalForward("OnCarAlarmTriggered", ET_Ignore, Param_Cell);

    RegPluginLibrary("skill_detect");
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvSelfClearThresh = CreateConVar(
        "sm_skill_selfclear_damage", "200",
        "How much damage a survivor must at least do to a smoker for him to count as self-clearing.",
        FCVAR_NONE, true, 0.0, false, 0.0
    );

    //g_cvDeathChargeHeight = CreateConVar("sm_skill_deathcharge_height", "400", "How much height distance a charger must take its victim for a deathcharge to be reported.", FCVAR_NONE, true, 0.0, false);

    g_cvHunterDPThresh = CreateConVar(
        "sm_skill_hunterdp_height", "400",
        "Minimum height of hunter pounce for it to count as a DP.",
        FCVAR_NONE, true, 0.0, false, 0.0
    );

    g_cvBHopMinInitSpeed = CreateConVar(
        "sm_skill_bhopinitspeed", "150",
        "The minimal speed of the first jump of a bunnyhopstreak (0 to allow 'hops' from standstill).",
        FCVAR_NONE, true, 0.0, false, 0.0
    );

    g_cvBHopContSpeed = CreateConVar(
        "sm_skill_bhopkeepspeed", "300",
        "The minimal speed at which hops are considered succesful even if not speed increase is made.",
        FCVAR_NONE, true, 0.0, false, 0.0
    );

    g_cvMaxPounceDistance = FindConVar("z_pounce_damage_range_max");
    if (g_cvMaxPounceDistance == null) {
        g_cvMaxPounceDistance = CreateConVar(
            "z_pounce_damage_range_max", "1000.0",
            "Not available on this server, added by skill_detect.",
            FCVAR_NONE, true, 0.0, false, 0.0
        );
    }

    g_cvMinPounceDistance = FindConVar("z_pounce_damage_range_min");
    if (g_cvMinPounceDistance == null) {
        g_cvMinPounceDistance = CreateConVar(
            "z_pounce_damage_range_min", "300.0",
            "Not available on this server, added by skill_detect.",
            FCVAR_NONE, true, 0.0, false, 0.0
        );
    }

    g_cvMaxPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
    if (g_cvMaxPounceDamage == null) {
        g_cvMaxPounceDamage = CreateConVar(
            "z_hunter_max_pounce_bonus_damage", "49",
            "Not available on this server, added by skill_detect.",
            FCVAR_NONE, true, 0.0, false, 0.0
        );
    }

    // hooks
    HookEvent("round_start",                Event_RoundStart,        EventHookMode_PostNoCopy);
    HookEvent("scavenge_round_start",       Event_RoundStart,        EventHookMode_PostNoCopy);

    HookEvent("player_spawn",               Event_PlayerSpawn,       EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,        EventHookMode_Pre);
    HookEvent("player_death",               Event_PlayerDeath,       EventHookMode_Pre);
    HookEvent("ability_use",                Event_AbilityUse,        EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,       EventHookMode_Post);
    HookEvent("player_shoved",              Event_PlayerShoved,      EventHookMode_Post);
    HookEvent("player_jump",                Event_PlayerJumped,      EventHookMode_Post);
    HookEvent("player_jump_apex",           Event_PlayerJumpApex,    EventHookMode_Post);

    HookEvent("player_now_it",              Event_PlayerBoomed,      EventHookMode_Post);

    HookEvent("jockey_ride",                Event_JockeyRide,        EventHookMode_Post);
    HookEvent("tongue_grab",                Event_TongueGrab,        EventHookMode_Post);
    HookEvent("tongue_pull_stopped",        Event_TonguePullStopped, EventHookMode_Post);
    HookEvent("choke_start",                Event_ChokeStart,        EventHookMode_Post);
    HookEvent("choke_stopped",              Event_ChokeStop,         EventHookMode_Post);
    HookEvent("charger_carry_start",        Event_ChargeCarryStart,  EventHookMode_Post);
    HookEvent("charger_carry_end",          Event_ChargeCarryEnd,    EventHookMode_Post);
    HookEvent("charger_impact",             Event_ChargeImpact,      EventHookMode_Post);
    HookEvent("charger_pummel_start",       Event_ChargePummelStart, EventHookMode_Post);

    HookEvent("player_incapacitated_start", Event_IncapStart,        EventHookMode_Post);
    HookEvent("triggered_car_alarm",        Event_TriggeredCarAlarm, EventHookMode_Post);

    HookEvent("weapon_fire",                Event_WeaponFire,        EventHookMode_Post);

    // tries
    g_smWeapons = new StringMap();
    g_smWeapons.SetValue("hunting_rifle",               WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_military",             WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_awp",                  WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_scout",                WPTYPE_SNIPER);
    g_smWeapons.SetValue("pistol_magnum",               WPTYPE_MAGNUM);

    g_smAbility = new StringMap();
    g_smAbility.SetValue("ability_lunge", ABL_HUNTERLUNGE);
    g_smAbility.SetValue("ability_throw", ABL_ROCKTHROW);

    g_smRocks = new StringMap();
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++) {
        g_hBoomerShoveTimer[i] = null;
    }
}

public void OnClientPutInServer(int iClient) {
    ResetHunter(iClient);
}

public void OnClientDisconnect(int iClient) {
    ResetHunter(iClient);
}

public void L4D_OnEnterGhostState(int iClient) {
    ResetHunter(iClient);
}

void Event_RoundStart(Event event, const char[] szName, bool bDontBroadcast)
{
    g_smRocks.Clear();
    g_iRocksBeingThrownCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        ResetHunter(i);
        g_bIsHopping[i] = false;

        for (int j = 1; j <= MaxClients; j++) {
            g_fVictimLastShove[i][j] = 0.0;
        }
    }
}

void Event_PlayerHurt(Event event, const char[] szName, bool bDontBroadcast)
{
    int iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
    int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int zClass;

    int iDmg     = GetEventInt(event, "dmg_health");
    int iDmgType = GetEventInt(event, "type");

    if (IsValidInfected(iVictim)) {
        zClass        = GetInfectedClass(iVictim);
        int iHealth   = GetEventInt(event, "health");
        int iHitGroup = GetEventInt(event, "hitgroup");

        if (iDmg <= 0) {
            return;
        }

        switch (zClass)
        {
            case SI_CLASS_HUNTER: {
                if (IsValidSurvivor(iAttacker)) {
                    /*
                    m_isAttemptingToPounce is set to 0 here if the hunter is actually skeeted
                    so the g_fHunterTracePouncing[victim] value indicates when the hunter was last seen pouncing in traceattack
                    (should be DIRECTLY before this event for every shot).
                    */
                    bool bIsPouncing = view_as<bool>(GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce") || g_fHunterTracePouncing[iVictim] != 0.0 && (GetGameTime() - g_fHunterTracePouncing[iVictim]) < 0.001);

                    if (iDmgType & DMG_BULLET || iDmgType & DMG_BUCKSHOT) {
                        if (iDmg > g_iHunterHealth[iVictim])
                            iDmg = g_iHunterHealth[iVictim]; // fix fake damage

                        g_iDmgDealt[iVictim][iAttacker] += iDmg;

                        if (!g_bShotCounted[iVictim][iAttacker]) {
                            g_iShotsDealt [iVictim][iAttacker]++;
                            g_bShotCounted[iVictim][iAttacker] = true;
                        }

                        if (iHealth == 0 && bIsPouncing) {
                            char szWeapon[32];
                            event.GetString("weapon", szWeapon, sizeof(szWeapon));

                            WpType eWeaponType;
                            g_smWeapons.GetValue(szWeapon, eWeaponType);

                            // headshot with bullet based weapon (only single shots) -- only snipers
                            if (eWeaponType == WPTYPE_SNIPER && iHitGroup == HITGROUP_HEAD) {
                                ExecuteForward_SkeetSniper(iAttacker, iVictim);
                            } else {
                                int iAssisters[4][4];
                                int iAssisterCount;

                                for (int i = 1; i <= MaxClients; i++) {
                                    if (i == iAttacker)
                                        continue;

                                    if (g_iDmgDealt[iVictim][i] > 0 && IsClientInGame(i)) {
                                        iAssisters[iAssisterCount][0] = i;
                                        iAssisters[iAssisterCount][1] = g_iDmgDealt[iVictim][i];
                                        iAssisterCount++;
                                    }
                                }

                                if (iAssisterCount > 0) {
                                    ExecuteForward_SkeetHurt(iAttacker, iVictim, g_iDmgDealt[iVictim][iAttacker], g_iShotsDealt[iVictim][iAttacker]);
                                } else {
                                    ExecuteForward_Skeet(iAttacker, iVictim, g_iShotsDealt[iVictim][iAttacker]);
                                }
                            }
                        }
                    } else if (iDmgType & DMG_SLASH || iDmgType & DMG_CLUB) {
                        if (iHealth == 0 && bIsPouncing) {
                            ExecuteForward_SkeetMelee(iAttacker, iVictim);
                        }
                    }
                }

                // store health for next damage it takes
                if (iHealth > 0)
                    g_iHunterHealth[iVictim] = iHealth;
                else
                    ResetHunter(iVictim);
            }

            case SI_CLASS_CHARGER: {
                if (IsValidSurvivor(iAttacker)) {
                    // check for levels
                    if (iHealth == 0 && (iDmgType & DMG_CLUB || iDmgType & DMG_SLASH)) {
                        int iAbilityEnt = GetEntPropEnt(iVictim, Prop_Send, "m_customAbility");
                        if (IsValidEntity(iAbilityEnt) && GetEntProp(iAbilityEnt, Prop_Send, "m_isCharging")) {
                            if (iDmg > g_iChargerHealth[iVictim])
                                iDmg = g_iChargerHealth[iVictim]; // fix fake damage

                            // charger was killed, was it a full level?
                            if (iHitGroup == HITGROUP_HEAD) {
                                ExecuteForward_ChargerLevel(iAttacker, iVictim);
                            } else {
                                ExecuteForward_ChargerLevelHurt(iAttacker, iVictim, iDmg);
                            }
                        }
                    }
                }

                // store health for next damage it takes
                if (iHealth > 0)
                    g_iChargerHealth[iVictim] = iHealth;
            }
            case SI_CLASS_SMOKER: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                g_iSmokerVictimDamage[iVictim] += iDmg;
            }
        }
    } else if (IsValidInfected(iAttacker)) {
        zClass = GetInfectedClass(iAttacker);

        switch (zClass) {
            case SI_CLASS_HUNTER: {
                // a hunter pounce landing is DMG_CRUSH
                if (iDmgType & DMG_CRUSH)
                    g_iPounceDamage[iAttacker] = iDmg;
            }
        }
    }

    // check for deathcharge flags
    if (IsValidSurvivor(iVictim)) {
        // debug
        if (iDmgType & DMG_DROWN || iDmgType & DMG_FALL)
            g_iVictimMapDmg[iVictim] += iDmg;

        if (iDmgType & DMG_DROWN && iDmg >= MIN_DC_TRIGGER_DMG) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_HURTLOTS;
        } else if (iDmgType & DMG_FALL && iDmg >= MIN_DC_FALL_DMG) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_HURTLOTS;
        }
    }
}

void Event_PlayerSpawn(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsValidInfected(iClient)) {
        return;
    }

    int zClass = GetInfectedClass(iClient);

    g_fSpawnTime[iClient]    = GetGameTime();
    g_fPinTime  [iClient][0] = 0.0;
    g_fPinTime  [iClient][1] = 0.0;

    switch (zClass)
    {
        case SI_CLASS_BOOMER:
        {
            g_bBoomerHitSomebody[iClient] = false;
            g_iBoomerGotShoved  [iClient] = 0;
            g_iBoomerKiller     [iClient] = 0;
            g_iBoomerShover     [iClient] = 0;

            if (g_hBoomerShoveTimer[iClient] != null) {
                KillTimer(g_hBoomerShoveTimer[iClient]);
                g_hBoomerShoveTimer[iClient] = null;
            }
        }

        case SI_CLASS_SMOKER:
        {
            g_bSmokerClearCheck  [iClient] = false;
            g_iSmokerVictim      [iClient] = 0;
            g_iSmokerVictimDamage[iClient] = 0;
        }

        case SI_CLASS_HUNTER:
        {
            SDKHook(iClient, SDKHook_TraceAttack, TraceAttack_Hunter);

            g_vPouncePosition[iClient][0] = 0.0;
            g_vPouncePosition[iClient][1] = 0.0;
            g_vPouncePosition[iClient][2] = 0.0;

            g_iHunterHealth[iClient] = GetClientHealth(iClient);
        }

        case SI_CLASS_CHARGER:
        {
            SDKHook(iClient, SDKHook_TraceAttack, TraceAttack_Charger);
            g_iChargerHealth[iClient] = GetClientHealth(iClient);
        }
    }
}

// player about to get incapped
void Event_IncapStart(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient    = GetClientOfUserId(GetEventInt(event, "userid"));
    int iAttackEnt = GetEventInt(event, "attackerentid");
    int iDmgType   = GetEventInt(event, "type");

    char szClassname[32];

    if (IsValidEntity(iAttackEnt))
    {
        GetEdictClassname(iAttackEnt, szClassname, sizeof(szClassname));
        if (strcmp(szClassname, TANK_ROCK) == 0) {
            g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_TRIGGER;
        }
    }

    float fFlow = L4D2Direct_GetFlowDistance(iClient);

    // drown is damage type
    if (iDmgType & DMG_DROWN)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_DROWN;

    if (fFlow < WEIRD_FLOW_THRESH)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_WEIRDFLOW;
}

// trace attacks on hunters
Action TraceAttack_Hunter(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iAmmoType, int iHitBox, int iHitGroup)
{
    // track pinning
    g_iSpecialVictim[iVictim] = GetEntPropEnt(iVictim, Prop_Send, "m_pounceVictim");

    if (!IsValidSurvivor(iAttacker) || !IsValidEdict(iInflictor))
        return Plugin_Continue;

    // track flight
    if (GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce")) {
        g_fHunterTracePouncing[iVictim] = GetGameTime();
    } else {
        g_fHunterTracePouncing[iVictim] = 0.0;
    }

    return Plugin_Continue;
}

Action TraceAttack_Charger(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iAmmoType, int iHitBox, int iHitGroup)
{
    // track pinning
    int iVictimA = GetEntPropEnt(iVictim, Prop_Send, "m_carryVictim");

    if (iVictimA != -1) {
        g_iSpecialVictim[iVictim] = iVictimA;
    } else {
        g_iSpecialVictim[iVictim] = GetEntPropEnt(iVictim, Prop_Send, "m_pummelVictim");
    }

    return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] szName, bool bDontBroadcast)
{
    int iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
    int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (event.GetBool("headshot"))
        ExecuteForward_HeadShot(iAttacker, iVictim);

    if (IsValidInfected(iVictim)) {
        int zClass = GetInfectedClass(iVictim);

        switch (zClass) {
            case SI_CLASS_SMOKER: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                if (g_bSmokerClearCheck[iVictim] && g_iSmokerVictim[iVictim] == iAttacker && g_iSmokerVictimDamage[iVictim] >= g_cvSelfClearThresh.IntValue) {
                    ExecuteForward_SmokerSelfClear(iAttacker, iVictim);
                } else {
                    g_bSmokerClearCheck[iVictim] = false;
                    g_iSmokerVictim    [iVictim] = 0;
                }
            }

            case SI_CLASS_BOOMER: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                g_iBoomerKiller[iVictim] = iAttacker;
                DataPack hPack;
                CreateDataTimer(0.2, Timer_BoomerKilledCheck, hPack, TIMER_FLAG_NO_MAPCHANGE);
                hPack.WriteCell(GetClientUserId(iVictim));
                hPack.WriteCell(iVictim);
            }

            case SI_CLASS_HUNTER: {
                ResetHunter(iVictim);
                if (g_iSpecialVictim[iVictim] > 0)
                    ExecuteForward_SpecialClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], SI_CLASS_HUNTER, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0);
            }

            case SI_CLASS_JOCKEY: {
                // check whether it was a clear
                if (g_iSpecialVictim[iVictim] > 0)
                    ExecuteForward_SpecialClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], SI_CLASS_JOCKEY, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0);
            }

            case SI_CLASS_CHARGER: {
                // is it someone carrying a survivor (that might be DC'd)?
                // switch charge victim to 'impact' check (reset checktime)
                if (!IsValidClient(g_iChargeVictim[iVictim]) || !IsClientInGame(g_iChargeVictim[iVictim]))
                    g_fChargeTime[g_iChargeVictim[iVictim]] = GetGameTime();

                // check whether it was a clear
                if (g_iSpecialVictim[iVictim] > 0)
                    ExecuteForward_SpecialClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], SI_CLASS_CHARGER, (g_fPinTime[iVictim][1] > 0.0) ? (GetGameTime() - g_fPinTime[iVictim][1]) : -1.0, (GetGameTime() - g_fPinTime[iVictim][0]));
            }
        }
    } else if (IsValidSurvivor(iVictim)) {
        int iDmgType = GetEventInt(event, "type");
        if (iDmgType & DMG_FALL) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_FALL;
        } else if (IsValidInfected(iAttacker) && iAttacker != g_iVictimCharger[iVictim]) {
            // if something other than the charger killed them, remember (not a DC)
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_KILLEDBYOTHER;
        }
    }
}

Action Timer_BoomerKilledCheck(Handle hTimer, DataPack dp)
{
    dp.Reset();
    int iUserId = dp.ReadCell();
    int iVictim = dp.ReadCell();

    float fTimeAlive  = GetGameTime() - g_fSpawnTime[iVictim];

    if (GetClientOfUserId(iUserId) != iVictim || g_bBoomerHitSomebody[iVictim])
    {
        g_iBoomerKiller[iVictim] = 0;
        fTimeAlive = 0.0;
        return Plugin_Stop;
    }

    if (!IsValidClient(iVictim) || !IsClientInGame(iVictim))
    {
        g_iBoomerKiller[iVictim] = 0;
        fTimeAlive = 0.0;
        return Plugin_Stop;
    }

    int iAttacker = g_iBoomerKiller[iVictim];
    if (!IsValidClient(iAttacker) || !IsClientInGame(iAttacker))
    {
        g_iBoomerKiller[iVictim] = 0;
        fTimeAlive = 0.0;
        return Plugin_Stop;
    }

    int   iShover     = g_iBoomerShover[iVictim];
    int   iShoveCount = g_iBoomerGotShoved[iVictim];

    ExecuteForward_BoomerPop(iAttacker, iVictim, IsValidSurvivor(iShover) ? iShover : -1, iShoveCount, fTimeAlive);

    g_iBoomerKiller[iVictim] = 0;
    return Plugin_Stop;
}

void Event_PlayerShoved(Event event, const char[] szName, bool bDontBroadcast)
{
    int iVictim   = GetClientOfUserId(GetEventInt(event, "userid"));
    int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    // check for boomers and clears
    switch (GetInfectedClass(iVictim))
    {
        case SI_CLASS_BOOMER:
        {
            if (g_hBoomerShoveTimer[iVictim] != null)
            {
                KillTimer(g_hBoomerShoveTimer[iVictim]);
                if (!g_iBoomerShover[iVictim] || !IsClientInGame(g_iBoomerShover[iVictim])) {
                    g_iBoomerShover[iVictim] = iAttacker;
                }
            } else {
                g_iBoomerShover[iVictim] = iAttacker;
            }
            g_hBoomerShoveTimer[iVictim] = CreateTimer(4.0, Timer_BoomerShoved, iVictim, TIMER_FLAG_NO_MAPCHANGE);
            g_iBoomerGotShoved[iVictim]++;
        }

        case SI_CLASS_HUNTER:
        {
            int iPinVictim = GetEntPropEnt(iVictim, Prop_Send, "m_pounceVictim");

            if (iPinVictim > 0) {
                ExecuteForward_SpecialClear(iAttacker, iVictim, iPinVictim, SI_CLASS_HUNTER, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0, true);
            }
        }

        case SI_CLASS_JOCKEY:
        {
            int iPinVictim = GetEntPropEnt(iVictim, Prop_Send, "m_jockeyVictim");

            if (iPinVictim > 0) {
                ExecuteForward_SpecialClear(iAttacker, iVictim, iPinVictim, SI_CLASS_JOCKEY, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0, true);
            }
        }
    }

    if (g_fVictimLastShove[iVictim][iAttacker] == 0.0 || (GetGameTime() - g_fVictimLastShove[iVictim][iAttacker]) >= SHOVE_TIME)
    {
        if (GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce")) {
            ExecuteForward_HunterDeadstop(iAttacker, iVictim);
        }

        g_fVictimLastShove[iVictim][iAttacker] = GetGameTime();
    }

    // check for shove on smoker by pull victim
    if (g_iSmokerVictim[iVictim] == iAttacker) {
        g_bSmokerShoved[iVictim] = true;
    }
}

Action Timer_BoomerShoved(Handle hTimer, int iVictim)
{
    g_hBoomerShoveTimer[iVictim] = null;
    g_iBoomerShover    [iVictim] = 0;
    return Plugin_Stop;
}

void Event_LungePounce(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim = GetClientOfUserId(GetEventInt(event, "victim"));

    g_fPinTime[iClient][0] = GetGameTime();

    // check if it was a DP
    // ignore if no real pounce start pos
    if (g_vPouncePosition[iClient][0] == 0.0 && g_vPouncePosition[iClient][1] == 0.0 && g_vPouncePosition[iClient][2] == 0.0) {
        return;
    }

    float vEndPos[3];
    GetClientAbsOrigin(iClient, vEndPos);

    float fHeight = g_vPouncePosition[iClient][2] - vEndPos[2];

    // from pounceannounce:
    // distance supplied isn't the actual 2d vector distance needed for damage calculation. See more about it at
    // http://forums.alliedmods.net/showthread.php?t=93207

    float fMin    = g_cvMinPounceDistance.FloatValue;
    float fMax    = g_cvMaxPounceDistance.FloatValue;
    float fMaxDmg = g_cvMaxPounceDamage.FloatValue;

    // calculate 2d distance between previous position and pounce position
    int iDistance = RoundToNearest(GetVectorDistance(g_vPouncePosition[iClient], vEndPos));

    // get damage using hunter damage formula
    // check if this is accurate, seems to differ from actual damage done!
    float fDamage = (((float(iDistance) - fMin) / (fMax - fMin)) * fMaxDmg) + 1.0;

    // apply bounds
    if (fDamage < 0.0) {
        fDamage = 0.0;
    } else if (fDamage > fMaxDmg + 1.0) {
        fDamage = fMaxDmg + 1.0;
    }

    DataPack hPack = CreateDataPack();
    CreateDataTimer(0.05, Timer_HunterHighPounce, hPack, TIMER_FLAG_NO_MAPCHANGE);
    WritePackCell(hPack, iClient);
    WritePackCell(hPack, iVictim);
    WritePackFloat(hPack, fDamage);
    WritePackFloat(hPack, fHeight);
}

Action Timer_HunterHighPounce(Handle hTimer, DataPack hPack)
{
    ResetPack(hPack);
    int	  iClient = ReadPackCell(hPack);
    int	  iVictim = ReadPackCell(hPack);
    float fDamage = ReadPackFloat(hPack);
    float fHeight = ReadPackFloat(hPack);

    ExecuteForward_HunterHighPounce(iClient, iVictim, g_iPounceDamage[iClient], fDamage, fHeight);
    return Plugin_Continue;
}

void Event_PlayerJumped(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidInfected(iClient))
    {
        int zClass = GetInfectedClass(iClient);
        if (zClass != SI_CLASS_JOCKEY) {
            return;
        }

        // where did jockey jump from?
        GetClientAbsOrigin(iClient, g_vPouncePosition[iClient]);
    } else if (IsValidSurvivor(iClient)) {
        // could be the start or part of a hopping streak
        float vVelocity[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVelocity);
        vVelocity[2] = 0.0; // safeguard

        float fLengthNew;
        float fLengthOld;
        fLengthNew = GetVectorLength(vVelocity);

        g_bHopCheck[iClient] = false;

        if (!g_bIsHopping[iClient])
        {
            if (fLengthNew >= g_cvBHopMinInitSpeed.FloatValue) {
                // starting potential hop streak
                g_fHopTopVelocity[iClient] = fLengthNew;
                g_bIsHopping[iClient]      = true;
                g_iHops[iClient]           = 0;
            }
        }
        else
        {
            // check for hopping streak
            fLengthOld = GetVectorLength(g_fLastHop[iClient]);

            // if they picked up speed, count it as a hop, otherwise, we're done hopping
            if (fLengthNew - fLengthOld > HOP_ACCEL_THRESH || fLengthNew >= g_cvBHopContSpeed.FloatValue) {
                g_iHops[iClient]++;

                // this should always be the case...
                if (fLengthNew > g_fHopTopVelocity[iClient])
                    g_fHopTopVelocity[iClient] = fLengthNew;
            } else {
                g_bIsHopping[iClient] = false;

                if (g_iHops[iClient]) {
                    ExecuteForward_BunnyHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
                    g_iHops[iClient] = 0;
                }
            }
        }

        g_fLastHop[iClient][0] = vVelocity[0];
        g_fLastHop[iClient][1] = vVelocity[1];
        g_fLastHop[iClient][2] = vVelocity[2];

        if (g_iHops[iClient] != 0)
            CreateTimer(HOP_CHECK_TIME, Timer_CheckHop, iClient, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // check when the player returns to the ground
    }
}

/*
 *
 */
Action Timer_CheckHop(Handle hTimer, any iClient)
{
    if (!IsValidClient(iClient) || !IsClientInGame(iClient) || !IsPlayerAlive(iClient)) {
        return Plugin_Stop;
    }

    // player back to ground = end of hop (streak)?
    if (GetEntityFlags(iClient) & FL_ONGROUND)
    {
        float vVelocity[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVelocity);
        vVelocity[2] = 0.0; // safeguard
        g_bHopCheck[iClient] = true;
        CreateTimer(HOPEND_CHECK_TIME, Timer_CheckHopStreak, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/*
 *
 */
Action Timer_CheckHopStreak(Handle hTimer, any iClient)
{
    if (!IsValidClient(iClient) || !IsClientInGame(iClient) || !IsPlayerAlive(iClient)) {
        return Plugin_Continue;
    }

    // check if we have any sort of hop streak, and report
    if (g_bHopCheck[iClient] && g_iHops[iClient])
    {
        ExecuteForward_BunnyHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
        g_bIsHopping     [iClient] = false;
        g_iHops          [iClient] = 0;
        g_fHopTopVelocity[iClient] = 0.0;
    }

    g_bHopCheck[iClient] = false;
    return Plugin_Continue;
}

void Event_PlayerJumpApex(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (g_bIsHopping[iClient])
    {
        float vVelocity[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVelocity);
        vVelocity[2] = 0.0;

        float fLength = GetVectorLength(vVelocity);
        if (fLength > g_fHopTopVelocity[iClient]) {
            g_fHopTopVelocity[iClient] = fLength;
        }
    }
}

void Event_JockeyRide(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim = GetClientOfUserId(GetEventInt(event, "victim"));

    if (!IsValidInfected(iClient) || !IsValidSurvivor(iVictim))
        return;

    g_fPinTime[iClient][0] = GetGameTime();
}

void Event_AbilityUse(Event event, const char[] szName, bool bDontBroadcast)
{
    // track hunters pouncing
    int  iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    char szAbilityName[32];
    GetEventString(event, "ability", szAbilityName, sizeof(szAbilityName));

    if (!IsValidClient(iClient) || !IsClientInGame(iClient)) {
        return;
    }

    Ability eAbility;
    if (!g_smAbility.GetValue(szAbilityName, eAbility)) {
        return;
    }

    switch (eAbility)
    {
        case ABL_HUNTERLUNGE: {
            // hunter started a pounce
            GetClientAbsOrigin(iClient, g_vPouncePosition[iClient]);
        }

        case ABL_ROCKTHROW: {
            // tank throws rock
            g_iTankRockClient[g_iRocksBeingThrownCount] = iClient;
            // safeguard
            if (g_iRocksBeingThrownCount < MAXPLAYERS + 1)
                g_iRocksBeingThrownCount ++;
        }
    }
}

// charger carrying
void Event_ChargeCarryStart(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim = GetClientOfUserId(GetEventInt(event, "victim"));

    if (!IsValidInfected(iClient)) {
        return;
    }

    g_fChargeTime[iClient]    = GetGameTime();
    g_fPinTime   [iClient][0] = g_fChargeTime[iClient];
    g_fPinTime   [iClient][1] = 0.0;

    if (!IsValidSurvivor(iVictim)) {
        return;
    }

    g_iChargeVictim [iClient] = iVictim;                    // store who we're carrying (as long as this is set, it's not considered an impact charge flight)
    g_iVictimCharger[iVictim] = iClient;                    // store who's charging whom
    g_iVictimFlags  [iVictim] = VICFLG_CARRIED;             // reset flags for checking later - we know only this now
    g_fChargeTime   [iVictim] = g_fChargeTime[iClient];
    g_iVictimMapDmg [iVictim] = 0;

    GetClientAbsOrigin(iVictim, g_fChargeVictimPos[iVictim]);

    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, iVictim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_ChargeImpact(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim = GetClientOfUserId(GetEventInt(event, "victim"));

    if (!IsValidInfected(iClient) || !IsValidSurvivor(iVictim)) {
        return;
    }

    // remember how many people the charger bumped into, and who, and where they were
    GetClientAbsOrigin(iVictim, g_fChargeVictimPos[iVictim]);

    g_iVictimCharger[iVictim] = iClient;           // store who we've bumped up
    g_iVictimFlags  [iVictim] = 0;                // reset flags for checking later
    g_fChargeTime   [iVictim] = GetGameTime();    // store time per victim, for impacts
    g_iVictimMapDmg [iVictim] = 0;

    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, iVictim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_ChargePummelStart(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IsValidInfected(iClient)) {
        return;
    }

    g_fPinTime[iClient][1] = GetGameTime();
}

void Event_ChargeCarryEnd(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IsValidClient(iClient)) {
        return;
    }

    g_fPinTime[iClient][1] = GetGameTime();

    // delay so we can check whether charger died 'mid carry'
    CreateTimer(0.1, Timer_ChargeCarryEnd, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ChargeCarryEnd(Handle hTimer, any iClient) {
    // set charge time to 0 to avoid deathcharge timer continuing
    g_iChargeVictim[iClient] = 0;    // unset this so the repeated timer knows to stop for an ongroundcheck
    return Plugin_Continue;
}

Action Timer_ChargeCheck(Handle hTimer, any iClient)
{
    if (!IsValidSurvivor(iClient)) {
        return Plugin_Stop;
    }

    // if something went wrong with the survivor or it was too long ago, forget about it
    if (!g_iVictimCharger[iClient] || g_fChargeTime[iClient] == 0.0 || (GetGameTime() - g_fChargeTime[iClient]) > MAX_CHARGE_TIME)
        return Plugin_Stop;

    // we're done checking if either the victim reached the ground, or died
    if (!IsPlayerAlive(iClient)) {
        // player died (this was .. probably.. a death charge)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_AIRDEATH;

        // check conditions now
        CreateTimer(0.0, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    } else if (GetEntityFlags(iClient) & FL_ONGROUND && g_iChargeVictim[g_iVictimCharger[iClient]] != iClient) {
        // survivor reached the ground and didn't die (yet)
        // the client-check condition checks whether the survivor is still being carried by the charger
        //      (in which case it doesn't matter that they're on the ground)

        // check conditions with small delay (to see if they still die soon)
        CreateTimer(CHARGE_END_CHECK, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

Action Timer_DeathChargeCheck(Handle hTimer, any iClient)
{
    if (!IsValidClient(iClient) || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    int iFlags = g_iVictimFlags[iClient];

    if (!IsPlayerAlive(iClient)) {
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        /*
            it's a deathcharge when:
                the survivor is dead AND
                    they drowned/fell AND took enough damage or died in mid-air
                    AND not killed by someone else
                    OR is in an unreachable spot AND dropped at least X height
                    OR took plenty of map damage

            old.. need?
                fHeight > g_cvDeathChargeHeight.FloatValue
        */

        float fHeight = g_fChargeVictimPos[iClient][2] - vPos[2];
        if (((iFlags & VICFLG_DROWN || iFlags & VICFLG_FALL) && (iFlags & VICFLG_HURTLOTS || iFlags & VICFLG_AIRDEATH) || (iFlags & VICFLG_WEIRDFLOW && fHeight >= MIN_FLOWDROPHEIGHT) || g_iVictimMapDmg[iClient] >= MIN_DC_TRIGGER_DMG) && !(iFlags & VICFLG_KILLEDBYOTHER))
            ExecuteForward_DeathCharge(g_iVictimCharger[iClient], iClient, fHeight, GetVectorDistance(g_fChargeVictimPos[iClient], vPos, false), view_as<bool>(iFlags & VICFLG_CARRIED));
    } else if ((iFlags & VICFLG_WEIRDFLOW || g_iVictimMapDmg[iClient] >= MIN_DC_RECHECK_DMG) && !(iFlags & VICFLG_WEIRDFLOWDONE)) {
        // could be incapped and dying more slowly
        // flag only gets set on preincap, so don't need to check for incap
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_WEIRDFLOWDONE;
        CreateTimer(CHARGE_END_RECHECK, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Continue;
}

void ResetHunter(int iTarget)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iDmgDealt[iTarget][i] = 0;
        g_iShotsDealt[iTarget][i] = 0;
    }
}

// entity creation
public void OnEntityCreated(int iEnt, const char[] szClassname)
{
    if (iEnt <= 0 || !IsValidEntity(iEnt)) {
        return;
    }

    if (strcmp(szClassname, TANK_ROCK) == 0)
    {
        char szRockKey[10];
        FormatEx(szRockKey, sizeof(szRockKey), "%x", iEnt);

        // store which tank is throwing what rock
        int iTank = ShiftTankThrower();
        g_smRocks.SetValue(szRockKey, iTank, true);
        SDKHook(iEnt, SDKHook_OnTakeDamageAlivePost, TakeDamageAlivePost_Rock);
    }
}

// entity destruction
public void OnEntityDestroyed(int iEnt) {
    char szKey[10];
    FormatEx(szKey, sizeof(szKey), "%x", iEnt);

    int iTank;
    if (!g_smRocks.GetValue(szKey, iTank))
        return;

    g_smRocks.Remove(szKey);
}

void TakeDamageAlivePost_Rock(int iVictim, int iAttacker, int iInflictor, float fDmg, int iDmgType, int iWeapon, const float vDmgForce[3], const float vDmgPos[3]) {
    if (GetEntProp(iVictim, Prop_Data, "m_iHealth") > 0)
        return;

    if (!IsValidClient(iAttacker) || !IsClientInGame(iAttacker))
        return;

    char szRockKey[10];
    FormatEx(szRockKey, sizeof(szRockKey), "%x", iVictim);

    int iTank;
    if (!g_smRocks.GetValue(szRockKey, iTank))
        return;

    ExecuteForward_RockSkeeted(iAttacker, iTank);
}

// boomer got somebody
void Event_PlayerBoomed(Event event, const char[] szName, bool bDontBroadcast) {
    int  iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    bool bByBoom   = event.GetBool("by_boomer");

    if (!g_bBoomerHitSomebody[iAttacker]) {
        if (IsValidSurvivor(g_iBoomerKiller[iAttacker]) && IsValidInfected(iAttacker) && IsValidSurvivor(g_iBoomerShover[iAttacker]))
            ExecuteForward_BoomerPopEarly(g_iBoomerKiller[iAttacker], iAttacker, g_iBoomerShover[iAttacker]);
    }

    if (bByBoom && IsValidInfected(iAttacker)) {
        g_bBoomerHitSomebody[iAttacker] = true;

        // check if it was vomit spray
        bool bByExplosion = event.GetBool("exploded");
        if (!bByExplosion) {
            // count amount of booms
            if (!g_iBoomerVomitHits[iAttacker])
                // check for boom count later
                CreateTimer(VOMIT_DURATION_TIME, Timer_BoomVomitCheck, iAttacker, TIMER_FLAG_NO_MAPCHANGE);
            g_iBoomerVomitHits[iAttacker]++;
        }
    }
}

// check how many booms landed
Action Timer_BoomVomitCheck(Handle hTimer, any iClient)
{
    ExecuteForward_BoomerVomitLanded(iClient, g_iBoomerVomitHits[iClient]);
    g_iBoomerVomitHits[iClient] = 0;
    return Plugin_Continue;
}

// smoker tongue cutting & self clears
void Event_TonguePullStopped(Event event, const char[] szName, bool bDontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim   = GetClientOfUserId(GetEventInt(event, "victim"));
    int iSmoker   = GetClientOfUserId(GetEventInt(event, "smoker"));
    int iReason   = GetEventInt(event, "release_type");

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iSmoker))
        return;

    // clear check - if the smoker itself was not shoved, handle the clear
    ExecuteForward_SpecialClear(iAttacker, iSmoker, iVictim, SI_CLASS_SMOKER, (g_fPinTime[iSmoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[iSmoker][1]) : -1.0, (GetGameTime() - g_fPinTime[iSmoker][0]), view_as<bool>(iReason != CUT_SLASH && iReason != CUT_KILL));

    if (iAttacker != iVictim)
        return;

    if (iReason == CUT_KILL) {
        g_bSmokerClearCheck[iSmoker] = true;
    } else if (g_bSmokerShoved[iSmoker]) {
        ExecuteForward_SmokerSelfClear(iAttacker, iSmoker, true);
    } else if (iReason == CUT_SLASH) {
        // check weapon
        char szWeapon[32];
        GetClientWeapon(iAttacker, szWeapon, sizeof(szWeapon));

        // this doesn't count the chainsaw, but that's no-skill anyway
        if (strcmp(szWeapon, "weapon_melee", false) == 0)
            ExecuteForward_TongueCut(iAttacker, iSmoker);
    }
}

void Event_TongueGrab(Event event, const char[] szName, bool bDontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim   = GetClientOfUserId(GetEventInt(event, "victim"));

    if (IsValidInfected(iAttacker) && IsValidSurvivor(iVictim))
    {
        // new pull, clean damage
        g_bSmokerClearCheck  [iAttacker]    = false;
        g_bSmokerShoved      [iAttacker]    = false;
        g_iSmokerVictim      [iAttacker]    = iVictim;
        g_iSmokerVictimDamage[iAttacker]    = 0;
        g_fPinTime           [iAttacker][0] = GetGameTime();
        g_fPinTime           [iAttacker][1] = 0.0;
    }
}

void Event_ChokeStart(Event event, const char[] szName, bool bDontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_fPinTime[iAttacker][0] == 0.0)
        g_fPinTime[iAttacker][0] = GetGameTime();
    g_fPinTime[iAttacker][1] = GetGameTime();
}

void Event_ChokeStop(Event event, const char[] szName, bool bDontBroadcast)
{
    int iAttacker = GetClientOfUserId(GetEventInt(event, "userid"));
    int iVictim   = GetClientOfUserId(GetEventInt(event, "victim"));
    int iSmoker   = GetClientOfUserId(GetEventInt(event, "smoker"));
    int iReason   = GetEventInt(event, "release_type");

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iSmoker))
        return;

    // if the smoker itself was not shoved, handle the clear
    ExecuteForward_SpecialClear(iAttacker, iSmoker, iVictim, SI_CLASS_SMOKER, (g_fPinTime[iSmoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[iSmoker][1]) : -1.0, (GetGameTime() - g_fPinTime[iSmoker][0]), view_as<bool>(iReason != CUT_SLASH && iReason != CUT_KILL));
}

// car alarm handling
void Event_TriggeredCarAlarm(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IsValidSurvivor(iClient))
        return;

    ExecuteForward_CarAlarmTriggered(iClient);
}

void Event_WeaponFire(Event event, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
    for (int i = 1; i <= MaxClients; i++) {
        g_bShotCounted[i][iClient] = false;
    }
}

// headshot
void ExecuteForward_HeadShot(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdHeadShot);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// boomer pop
void ExecuteForward_BoomerPop(int iAttacker, int iVictim, int iShover, int iShoveCount, float fTimeAlive)
{
    Call_StartForward(g_fwdBoomerPop);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iShover);
    Call_PushCell(iShoveCount);
    Call_PushFloat(fTimeAlive);
    Call_Finish();
}

void ExecuteForward_BoomerPopEarly(int iAttacker, int iVictim, int iShover)
{
    Call_StartForward(g_fwdBoomerPopEarly);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iShover);
    Call_Finish();
}

// charger level
void ExecuteForward_ChargerLevel(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdChargerLevel);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// charger level hurt
void ExecuteForward_ChargerLevelHurt(int iAttacker, int iVictim, int iDmg)
{
    Call_StartForward(g_fwdChargerLevelHurt);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iDmg);
    Call_Finish();
}

// deadstops
void ExecuteForward_HunterDeadstop(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdHunterDeadstop);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// skeet
void ExecuteForward_SkeetSniper(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdSkeetSniper);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

void ExecuteForward_SkeetMelee(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdSkeetMelee);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

void ExecuteForward_SkeetHurt(int iAttacker, int iVictim, int iDmg, int iShots)
{
    Call_StartForward(g_fwdSkeetHurt);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iDmg);
    Call_PushCell(iShots);
    Call_Finish();
}

void ExecuteForward_Skeet(int iAttacker, int iVictim, int iShots)
{
    Call_StartForward(g_fwdSkeet);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iShots);
    Call_Finish();
}

// smoker clears
void ExecuteForward_TongueCut(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdTongueCut);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

void ExecuteForward_SmokerSelfClear(int iAttacker, int iVictim, bool bWithShove = false)
{
    Call_StartForward(g_fwdSmokerSelfClear);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(bWithShove);
    Call_Finish();
}

void ExecuteForward_RockSkeeted(int iAttacker, int iVictim)
{
    Call_StartForward(g_fwdRockSkeeted);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// highpounces
void ExecuteForward_HunterHighPounce(int iAttacker, int iVictim, int iActualDmg, float fCalculatedDmg, float fHeight)
{
    Call_StartForward(g_fwdHunterHighPounce);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iActualDmg);
    Call_PushFloat(fCalculatedDmg);
    Call_PushFloat(fHeight);
    Call_PushCell((fHeight >= g_cvHunterDPThresh.FloatValue) ? 1 : 0);
    Call_Finish();
}

// deathcharges
void ExecuteForward_DeathCharge(int iAttacker, int iVictim, float fHeight, float fDistance, bool bCarried = true)
{
    Call_StartForward(g_fwdDeathCharge);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushFloat(fHeight);
    Call_PushFloat(fDistance);
    Call_PushCell((bCarried) ? 1 : 0);
    Call_Finish();
}

// SI clears (cleartimeA = pummel/pounce/ride/choke, cleartimeB = tongue drag, charger carry)
void ExecuteForward_SpecialClear(int iAttacker, int iVictim, int iPinVictim, int zClass, float fClearTimeA, float fClearTimeB, bool bWithShove = false)
{
    Call_StartForward(g_fwdSpecialClear);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iPinVictim);
    Call_PushCell(zClass);
    Call_PushFloat(fClearTimeA);
    Call_PushFloat(fClearTimeB);
    Call_PushCell((bWithShove) ? 1 : 0);
    Call_Finish();
}

// booms
void ExecuteForward_BoomerVomitLanded(int iAttacker, int iBoomCount)
{
    Call_StartForward(g_fwdBoomerVomitLanded);
    Call_PushCell(iAttacker);
    Call_PushCell(iBoomCount);
    Call_Finish();
}

// bhaps
void ExecuteForward_BunnyHopStreak(int iSurvivor, int iStreak, float fMaxVelocity)
{
    Call_StartForward(g_fwdBunnyHopStreak);
    Call_PushCell(iSurvivor);
    Call_PushCell(iStreak);
    Call_PushFloat(fMaxVelocity);
    Call_Finish();
}

// car alarms
void ExecuteForward_CarAlarmTriggered(int iSurvivor)
{
    Call_StartForward(g_fwdCarAlarmTriggered);
    Call_PushCell(iSurvivor);
    Call_Finish();
}

/**
 * Selects the Tank client currently throwing a rock and
 * shifts the thrower queue if there is more than one.
 *
 * @return  Client index of the first Tank in the thrower queue,
 *          or -1 if there are no Tanks throwing rocks.
 */
int ShiftTankThrower()
{
    int iTank = -1;

    if (g_iRocksBeingThrownCount <= 0) {
        return iTank;
    }

    iTank = g_iTankRockClient[0];

    // shift the tank array downwards, if there are more than 1 throwers
    if (g_iRocksBeingThrownCount > 1) {
        for (int x = 1; x <= g_iRocksBeingThrownCount; x++) {
            g_iTankRockClient[x - 1] = g_iTankRockClient[x];
        }
    }

    g_iRocksBeingThrownCount--;
    return iTank;
}

/**
 * Checks whether the player is a Survivor.
 *
 * @param iClient   Client index.
 * @return          true if the client is on the Survivor team, otherwise false.
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * Checks whether the player is Infected.
 *
 * @param iClient   Client index.
 * @return          true if the client is on the Infected team, otherwise false.
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Validates whether the client index is within a valid range.
 *
 * @param iClient   Client index.
 * @return          true if the client index is valid, otherwise false.
 */
bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Get the zombie player class.
 */
int GetInfectedClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

/**
 * Retrieves the zombie class for an Infected player.
 *
 * @param iClient   Client index of the Infected player.
 * @return          Integer ID of the zombie class (see m_zombieClass constants).
 */
bool IsValidSurvivor(int iClient) {
    return IsValidClient(iClient) && IsClientInGame(iClient) && IsClientSurvivor(iClient);
}

/**
 * Checks whether the client is a valid in-game Survivor.
 *
 * @param iClient   Client index.
 * @return          true if the client exists, is in-game, and is a Survivor.
 */
bool IsValidInfected(int iClient) {
    return IsValidClient(iClient) && IsClientInGame(iClient) && IsClientInfected(iClient);
}
