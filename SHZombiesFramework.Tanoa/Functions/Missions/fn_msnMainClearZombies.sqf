/*
Function: SHZ_fnc_msnMainClearZombies

Description:
    Players must clear out zombies from an area.
    Function must be ran in scheduled environment.

Parameters:
    PositionATL area:
        (Optional, default [])
        If specified, the given area is used for the mission instead of
        attempting to find a suitable area.

Author:
    thegamecracks

*/
params [["_area", []]];

if (_area isEqualTo []) then {
    private _location = selectRandom nearestLocations [
        [worldSize / 2, worldSize / 2],
        ["NameVillage", "NameCity"],
        sqrt 2 / 2 * worldSize
    ];
    private _radius = selectMax size _location * 2;
    _area = [locationPosition _location, _radius, _radius, 0, false];
};
if (_area isEqualTo []) exitWith {
    diag_log text format ["%1: No area found", _fnc_scriptName];
};

private _areaMarker = [["SHZ_mainMission"], _area, true] call SHZ_fnc_createAreaMarker;
_areaMarker setMarkerBrushLocal "FDiagonal";
_areaMarker setMarkerColorLocal "ColorRed";
_areaMarker setMarkerAlpha 0.7;

private _killCountMarker = [
    ["SHZ_mainMission_killCount"],
    _area # 0 vectorAdd [_area # 1 + 50, 0, 0]
] call SHZ_fnc_createLocalMarker;
_killCountMarker setMarkerColorLocal "ColorRed";
_killCountMarker setMarkerTypeLocal "KIA";
_killCountMarker setMarkerAlpha 0.7;

private _taskID = [blufor, "", "mainClearZombies", _area # 0, "CREATED", -1, true, "attack"] call SHZ_fnc_taskCreate;

private _killThreshold = 600 + count allPlayers * 20 + floor random 251;
private _kills = createHashMap;
private _getKillCount = {
    private _total = 0;
    {_total = _total + _y} forEach _kills;
    _total
};

private _killEH = addMissionEventHandler [
    "EntityKilled",
    {
        params ["_killed", "_killer", "_instigator"];
        if (isNull _instigator) then {
            // UAV/UGV player operated road kill
            _instigator = UAVControl vehicle _killer # 0;
        };
        if (isNull _instigator) then {
            // player driven vehicle road kill
            _instigator = _killer;
        };
        if (isNull _instigator || {!isPlayer _instigator}) exitWith {};

        private _uid = getPlayerUID _instigator;
        if (_uid isEqualTo "") exitWith {};

        if !([side group _instigator, side group _killed] call BIS_fnc_sideIsEnemy) exitWith {};

        _thisArgs params ["_area", "_kills"];
        if !(_killed inArea _area) exitWith {};

        _kills set [_uid, (_kills getOrDefault [_uid, 0]) + 1];
    },
    [_area, _kills]
];

private _supportZombieBias = random 14 - 7;
private _supportTypes = [
    "demons",  1 + (_supportZombieBias max 0),
    "raiders", 1 - (_supportZombieBias min 0)
];
private _supportLimitBase = 20 + floor (_area # 1 / 50);
private _supportUnits = [];
private _getSupportUnitCount = {
    [_supportUnits, {alive _x}] call SHZ_fnc_shrinkCount
};
private _spawnSupportUnits = {
    private _supportType = selectRandomWeighted _supportTypes;
    switch (_supportType) do {
        case "demons": {
            [
                1 + floor random (3 + count allPlayers / 10),
                "demons",
                SHZ_zombieSide,
                _area # 0,
                _area # 1 * 0.5,
                1,
                [[_supportUnits, {
                    params ["_unit", "_supportUnits"];
                    _supportUnits pushBack _unit;
                }]]
            ] spawn SHZ_fnc_hordeSpawn;
        };
        case "raiders": {
            private _pos = [_area # 0, _area # 1, 100] call SHZ_fnc_randomPosHidden;
            if (_pos isEqualTo [0,0]) exitWith {};

            private _quantity = 1 + floor random (3 + count allPlayers / 5);
            private _group = [_quantity, _pos, 50, true] call SHZ_fnc_spawnRaiders;
            private _waypoint = _group addWaypoint [_pos, 0];
            _waypoint setWaypointType "SAD";
            _waypoint setWaypointCompletionRadius 20;
            _supportUnits append units _group;
        };
        default {throw format ["Unknown support type %1", _supportType]};
    };
};

private _lastKillCount = -1;
private _lastKillCountTime = -1;
while {true} do {
    sleep 10;

    private _now = diag_tickTime;
    private _killCount = call _getKillCount;

    if (_killCount >= _killThreshold) exitWith {
        [_taskID, "SUCCEEDED"] spawn SHZ_fnc_taskEnd;
    };

    if (_now >= _lastKillCountTime + 30 && {_killCount isNotEqualTo _lastKillCount}) then {
        _lastKillCount = _killCount;
        _lastKillCountTime = _now;
        [_killCountMarker, _killCount, _killThreshold] remoteExec [
            "SHZ_fnc_updateKillCountMarker",
            [0, -2] select isDedicated
        ];
    };

    private _supportLimit = _supportLimitBase + count allPlayers;
    if (
        random 1 < 0.3 + count allPlayers / 50
        && {call _getSupportUnitCount < _supportLimit
        && {[allPlayers, _area] call SHZ_fnc_anyInArea}}
    ) then {
        call _spawnSupportUnits;
    };
};

removeMissionEventHandler ["EntityKilled", _killEH];
deleteMarker _areaMarker;
deleteMarker _killCountMarker;
[_supportUnits] call SHZ_fnc_queueGCDeletion;
[_fnc_scriptName, keys _kills, 500] call SHZ_fnc_addCompletedMission;
