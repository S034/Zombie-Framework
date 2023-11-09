/*
Function: SHZ_fnc_createSafezone

Description:
    Creates a safezone marker.

Parameters:
    Array area:
        The safezone area in the format [center, a, b, angle, isRectangle].
        Similar to the format used for inArea except that c is ignored.
    Boolean local:
        (Optional, default false)
        If true, the marker will be local to the client.
        Recommended to enable this for network optimization if you need
        to customize the marker.

Returns:
    String
        The name of the marker created, or an empty string if unsuccessful.

Author:
    thegamecracks

*/
params ["_area", ["_local", false]];
_area params ["_center", "_a", "_b", "_angle", "_isRectangle"];
private _marker = "";

// Possibly prone to race conditions if more than one client uses this function
isNil {
    _marker = call SHZ_fnc_randomSafezoneID;
    _marker = createMarkerLocal [_marker, _center];
};

if (_marker isEqualTo "") exitWith {_marker};

private _shape = ["ELLIPSE", "RECTANGLE"] select _isRectangle;
_marker setMarkerShapeLocal _shape;
_marker setMarkerDirLocal _angle;
_marker setMarkerSizeLocal [_a, _b];
if (_local) then {_marker setMarkerAlphaLocal 0} else {_marker setMarkerAlpha 0};

_marker
