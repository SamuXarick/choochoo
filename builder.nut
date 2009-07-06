class Builder extends Task {
	
	relativeCoordinates = null;
	location = null;
	rotation = null;
	
	constructor(location, rotation = Rotation.ROT_0) {
		this.relativeCoordinates = RelativeCoordinates(location, rotation);
		this.location = location;
		this.rotation = rotation;
	}
	
	function GetLocationString(tile = null) {
		if (!tile) tile = this.location;
		return "(" + AIMap.GetTileX(tile) + ", " + AIMap.GetTileY(tile) + ")";
	}
	
	function GetTile(coordinates) {
		return relativeCoordinates.GetTile(coordinates);
	}
	
	/**
	 * Build a non-diagonal segment of track.
	 */
	function BuildSegment(start, end) {
		local from, to;
		if (start[0] == end[0]) {
			from = [start[0], start[1] - 1];
			to = [end[0], end[1] + 1];
		} else {
			from = [start[0] - 1, start[1]];
			to = [end[0] + 1, end[1]];
		}
		
		BuildRail(from, start, to);
	}
	
	/**
	 * Build a straight piece of track, excluding 'from' and 'to'.
	 */
	function BuildRail(from, on, to) {
		AIRail.BuildRail(GetTile(from), GetTile(on), GetTile(to));
		CheckError();
	}
	
	/**
	 * Build a signal.
	 */
	function BuildSignal(tile, front) {
		AIRail.BuildSignal(GetTile(tile), GetTile(front), AIRail.SIGNALTYPE_PBS_ONEWAY);
		CheckError();
	}
	
	/**
	 * Build a depot.
	 */
	function BuildDepot(tile, front) {
		AIRail.BuildRailDepot(GetTile(tile), GetTile(front));
		CheckError();
	}
	
}

class BuildCrossing extends Builder {
	
	network = null;
	
	constructor(location, network) {
		Builder.constructor(location);
		this.network = network;
	}
	
	function Run() {
		// four segments of track
		BuildSegment([0,1], [3,1]);
		BuildSegment([0,2], [3,2]);
		BuildSegment([1,0], [1,3]);
		BuildSegment([2,0], [2,3]);
		
		// outer diagonals (clockwise)
		BuildRail([1,0], [1,1], [0,1]);
		BuildRail([0,2], [1,2], [1,3]);
		BuildRail([3,2], [2,2], [2,3]);
		BuildRail([2,0], [2,1], [3,1]);
		
		// long inner diagonals
		//BuildRail([0,1], [1,1], [2,3]);
		//BuildRail([0,2], [1,2], [2,0]);
		//BuildRail([1,3], [1,2], [3,1]);
		//BuildRail([3,2], [2,2], [1,0]);
		
		// inner diagonals (clockwise)
		BuildRail([2,1], [1,1], [1,2]);
		BuildRail([1,1], [1,2], [2,2]);
		BuildRail([2,1], [2,2], [1,2]);
		BuildRail([1,1], [2,1], [2,2]);
		
		// signals (clockwise)
		// initially, all signals face outwards to block trains off from unfinished tracks
		BuildSignal([0,1], [-1, 1]);
		BuildSignal([0,2], [-1, 2]);
		BuildSignal([1,3], [ 1, 4]);
		BuildSignal([2,3], [ 2, 4]);
		BuildSignal([3,2], [ 4, 2]);
		BuildSignal([3,1], [ 4, 1]);
		BuildSignal([2,0], [ 2,-1]);
		BuildSignal([1,0], [ 1,-1]);
		
		// cap entrances off with depots
		//BuildDepot([-1,1], [0,1]);
		//BuildDepot([-1,2], [0,2]);
		//BuildDepot([ 1,4], [1,3]);
		//BuildDepot([ 2,4], [2,3]);
		//BuildDepot([ 4,2], [3,2]);
		//BuildDepot([ 4,1], [3,1]);
		//BuildDepot([2,-1], [2,0]);
		//BuildDepot([1,-1], [1,0]);
		
		world.crossings[location] <- Crossing(location);
		tasks.push(ExtendCrossing(location, Direction.NE, network));
		tasks.push(ExtendCrossing(location, Direction.SE, network));
		tasks.push(ExtendCrossing(location, Direction.SW, network));
		tasks.push(ExtendCrossing(location, Direction.NW, network));
	}
	
	function _tostring() {
		return "BuildCrossing " + GetLocationString();
	}
}

/**
 * 2-platform terminus station.
 */
class BuildTerminusStation extends Builder {
	
	network = null;
	platformLength = null;
	
	constructor(location, rotation, network, platformLength = 3) {
		Builder.constructor(location, rotation);
		this.network = network;
		this.platformLength = platformLength;
	}
	
	function Run() {
		BuildPlatforms();
		local p = platformLength;
		BuildSegment([0, p], [0, p+1]);
		BuildSegment([1, p], [1, p+1]);
		BuildRail([0, p-1], [0, p], [1, p+1]);
		BuildRail([1, p-1], [1, p], [0, p+1]);
		BuildSignal([0, p+1], [0, p+2]);
		BuildSignal([1, p+1], [1, p]);
		world.stations[location] <- TerminusStation(location, rotation, platformLength);
		network.stations.append(AIStation.GetStationID(location));
	}
	
	/**
	 * Build station platforms. Returns stationID.
	 */
	function BuildPlatforms() {
		// template is oriented NW->SE
		local direction;
		if (this.rotation == Rotation.ROT_0 || this.rotation == Rotation.ROT_180) {
			direction = AIRail.RAILTRACK_NW_SE;
		} else {
			direction = AIRail.RAILTRACK_NE_SW;
		}
		
		// on the map, location of the station is the topmost tile
		local platform1;
		local platform2;
		if (this.rotation == Rotation.ROT_0) {
			platform1 = GetTile([0, 0]);
			platform2 = GetTile([1, 0]);
		} else if (this.rotation == Rotation.ROT_90) {
			platform1 = GetTile([0, platformLength-1]);
			platform2 = GetTile([1, platformLength-1]);
		} else if (this.rotation == Rotation.ROT_180) {
			platform1 = GetTile([0, platformLength-1]);
			platform2 = GetTile([1, platformLength-1]);
		} else if (this.rotation == Rotation.ROT_270) {
			platform1 = GetTile([0,0]);
			platform2 = GetTile([1,0]);
		} else {
			throw "invalid rotation";
		}
		
		AIRail.BuildRailStation(platform1, direction, 1, platformLength, AIStation.STATION_NEW);
		CheckError();
		AIRail.BuildRailStation(platform2, direction, 1, platformLength, AIStation.STATION_JOIN_ADJACENT);
		CheckError();
		
		return AIStation.GetStationID(platform1);
	}
	
	function _tostring() {
		return "BuildTerminusStation " + GetLocationString();
	}
}

/**
 * Single platform RoRo station - obsolete code.
 */
class BuildRoRoStation extends Builder {
	
	constructor(location) {
		Builder.constructor(location);
	}
	
	function Run() {
		AIRail.BuildRailStation(location, AIRail.RAILTRACK_NE_SW, 1, 3, AIStation.STATION_NEW);
		CheckError();
		AIRail.BuildRailTrack(GetTile(location, [3,0]), AIRail.RAILTRACK_NE_SW);
		CheckError();
		AIRail.BuildRailTrack(GetTile(location, [-1,0]), AIRail.RAILTRACK_NE_SW);
		CheckError();
		BuildSignal([3,0], [4,0]);
		BuildSignal([-1,0], [-2,0]);
	}
	
	function _tostring() {
		return "BuildRoRoStation " + GetLocationString();
	}
}

/**
 * Increase the capture area of a train station by joining bus stations to it.
 */
class BuildBusStations extends Builder {

	stationTile = null;
	town = null;
		
	constructor(stationTile, town) {
		this.stationTile = stationTile;
		this.town = town;
	}
	
	function _tostring() {
		return "BuildBusStations " + AITown.GetName(town);
	}
	
	function Run() {
		// consider the area between the station and the center of town
		local area = AITileList();
		area.AddRectangle(stationTile, AITown.GetLocation(town));
		
		area.Valuate(AIRoad.IsRoadTile);
		area.KeepValue(1);
		
		area.Valuate(AIMap.DistanceManhattan, stationTile);
		area.Sort(AIList.SORT_BY_VALUE, true);
		
		// try all road tiles; if a station is built, don't build another in its vicinity
		for (local tile = area.Begin(); area.HasNext(); tile = area.Next()) {
			if (BuildStationAt(tile)) {
				area.RemoveRectangle(tile - AIMap.GetTileIndex(1, 1), tile + AIMap.GetTileIndex(1, 1));
			}
		}
	}
	
	function BuildStationAt(tile) {
		if (BuildStation(tile, true) || BuildStation(tile, false)) {
			return true;
		}
		
		return false;
	}
	
	function BuildStation(tile, facing) {
		local front = tile + (facing ? AIMap.GetTileIndex(0,1) : AIMap.GetTileIndex(1,0));
		return AIRoad.BuildDriveThroughRoadStation(tile, front, AIRoad.ROADVEHTYPE_BUS, AIStation.GetStationID(stationTile));
	}
}

class BuildTrack extends Builder {
	
	SIGNAL_INTERVAL = 3;
	DEPOT_INTERVAL = 15;
	
	a = null;
	b = null;
	c = null;
	d = null;
	ignored = [];
	forward = null;
	network = null;
	path = null;
	count = null;
	lastDepot = null;
	
	constructor(from, to, ignored, forward, network) {
		this.a = from[0];
		this.b = from[1];
		this.c = to[0];
		this.d = to[1];
		this.ignored = ignored;
		this.forward = forward;
		this.network = network;
		this.count = 1;
		this.lastDepot = count;
	}
	
	function _tostring() {
		return "BuildTrack from " + Get;
	}
	
	function Run() {
		/*
		AISign.BuildSign(a, "a");
		AISign.BuildSign(b, "b");
		AISign.BuildSign(c, "c");
		AISign.BuildSign(d, "d");
		*/
		
		if (!path) path = FindPath(a, b, c, d, ignored);
		if (!path) throw FAILED;
		BuildPath(path);
	}
	
	function FindPath(a, b, c, d, ignored) {
		local pathfinder = Rail();
		pathfinder.cost.max_cost = pathfinder.cost.tile * 4 * AIMap.DistanceManhattan(a, d);
		pathfinder.estimate_multiplier = 2;
		
		pathfinder.cost.diagonal_tile = 150;
		pathfinder.cost.bridge_per_tile = 400;
		pathfinder.InitializePath([[b, a]], [[c, d]], ignored);
		
		Debug("Pathfinding...");
		return pathfinder.FindPath(AIMap.DistanceManhattan(a, d) * 10 * TICKS_PER_DAY);
	}
	
	function BuildPath(path) {
		Debug("Building...");
		local prev = null;
		local prevprev = null;
		local prevprevprev = null;
		while (path != null) {
			if (prevprev != null) {
				if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
					if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
						AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev);
						CheckError();
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
						AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), prev, path.GetTile());
						CheckError();
					}
					prevprev = prev;
					prev = path.GetTile();
					path = path.GetParent();
				} else {
					local built = AIRail.BuildRail(prevprev, prev, path.GetTile());
					CheckError();
					
					// since we can be restarted, we can process a tile more than once
					// don't build signals again, or they'll be flipped around!
					local front = forward ? path.GetTile() : prevprev;
					if (count % SIGNAL_INTERVAL == 0 && AIRail.GetSignalType(prev, front) == AIRail.SIGNALTYPE_NONE) {
						AIRail.BuildSignal(prev, front, AIRail.SIGNALTYPE_NORMAL);
					}
					
					local possibleDepot = prevprevprev && path.GetParent();
					local depotSite = possibleDepot ? GetDepotSite(prevprevprev, prevprev, prev, path.GetTile(), path.GetParent().GetTile(), forward) : null;
					if (count % SIGNAL_INTERVAL == 1 && count - lastDepot > DEPOT_INTERVAL && depotSite) {
						if (AIRail.BuildRailDepot(depotSite, prev) &&
							AIRail.BuildRail(depotSite, prev, prevprev) &&
							AIRail.BuildRail(depotSite, prev, path.GetTile())) {
							// success
							lastDepot = count;
							network.depots.append(depotSite);
						} else {
							// TODO: clean up
						}							
					}
					
					if (built) count++;
				}
			}
			if (path != null) {
				prevprevprev = prevprev;
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			}
		}
		
		Debug("Done!");
	}
	
	/**
	 * Return a tile suitable for building a depot, or null.
	 */
	function GetDepotSite(prevprev, prev, tile, next, nextnext, forward) {
		// depots are built off to the right side of the track
		// site is suitable if the tiles are in a straight X or Y line
		local coordinates = [
			TileCoordinates(prevprev),
			TileCoordinates(prev),
			TileCoordinates(tile),
			TileCoordinates(next),
			TileCoordinates(nextnext)
		];
		
		if (MatchCoordinates(coordinates, 0)) {
			// same X
			if (coordinates[0][1] < coordinates[1][1]) {
				// increasing Y
				return AIMap.GetTileIndex(coordinates[2][0] + (forward ? -1 : 1), coordinates[2][1]);
			} else {
				// decreasing Y
				return AIMap.GetTileIndex(coordinates[2][0] + (forward ? 1 : -1), coordinates[2][1]);
			}
			
		} else if (MatchCoordinates(coordinates, 1)) {
			// same Y
			if (coordinates[0][0] < coordinates[1][0]) {
				// increasing X
				return AIMap.GetTileIndex(coordinates[2][0], coordinates[2][1] + (forward ? 1 : -1));
			} else {
				// decreasing X
				return AIMap.GetTileIndex(coordinates[2][0], coordinates[2][1] + (forward ? -1 : 1));
			}
		}
		
		return null;
	}
	
	/**
	 * Test whether the X or Y coordinates of a list are all the same.
	 */
	function MatchCoordinates(coordinates, index) {
		local value = coordinates[0][index];
		foreach (c in coordinates) {
			if (c[index] != value) return false;
		}
		
		return true;
	}
	
	function TileCoordinates(tile) {
		return [AIMap.GetTileX(tile), AIMap.GetTileY(tile)];
	}
}

class ConnectStation extends Builder {
	
	crossingTile = null;
	direction = null;
	stationTile = null;
	network = null;
	bt1 = null;
	bt2 = null;
	
	constructor(crossingTile, direction, stationTile, network) {
		this.crossingTile = crossingTile;
		this.direction = direction;
		this.stationTile = stationTile;
		this.network = network;
	}
	
	function Run() {
		local crossing = world.crossings[crossingTile];
		local station = world.stations[stationTile];
		
		// if we ran these subtasks as a task list, we can't signal failure to our parent task list
		// so, we run them inline, making sure we can be restarted
		// TODO: clean this up?
		
		if (bt1 == null) {
			local reserved = station.GetReservedEntranceSpace();
			reserved.extend(crossing.GetReservedExitSpace(direction));
			bt1 = BuildTrack(station.GetExit(), crossing.GetEntrance(direction), reserved, true, network);
		}
		
		if (bt2 == null) {
			local reserved = station.GetReservedExitSpace();
			reserved.extend(crossing.GetReservedEntranceSpace(direction));
			bt2 = BuildTrack(Swap(station.GetEntrance()), Swap(crossing.GetExit(direction)), reserved, false, network);
		}
		
		bt1.Run();
		bt2.Run();
		
		// building another signal on the tile will flip it
		local exit = crossing.GetExit(direction);
		AIRail.BuildSignal(exit[0], exit[1], AIRail.SIGNALTYPE_PBS_ONEWAY);
	}
	
	function Swap(tiles) {
		return [tiles[1], tiles[0]];
	}
	
	function _tostring() {
		return "ConnectStation";
	}
}

class ConnectCrossing extends Builder {
	
	fromCrossingTile = null;
	fromDirection = null;
	toCrossingTile = null;
	toDirection = null;
	network = null;
	bt1 = null;
	bt2 = null;
	
	constructor(fromCrossingTile, fromDirection, toCrossingTile, toDirection, network) {
		this.fromCrossingTile = fromCrossingTile;
		this.fromDirection = fromDirection;
		this.toCrossingTile = toCrossingTile;
		this.toDirection = toDirection;
		this.network = network;
	}
	
	function Run() {
		local fromCrossing = world.crossings[fromCrossingTile];
		local toCrossing = world.crossings[toCrossingTile];
		
		if (bt1 == null) {
			local reserved = toCrossing.GetReservedEntranceSpace(toDirection);
			reserved.extend(fromCrossing.GetReservedExitSpace(fromDirection));
			bt1 = BuildTrack(toCrossing.GetExit(toDirection), fromCrossing.GetEntrance(fromDirection), reserved, true, network);
		}
		
		if (bt2 == null) {
			local reserved = toCrossing.GetReservedExitSpace(toDirection);
			reserved.extend(fromCrossing.GetReservedEntranceSpace(fromDirection));
			bt2 = BuildTrack(Swap(toCrossing.GetEntrance(toDirection)), Swap(fromCrossing.GetExit(fromDirection)), reserved, false, network);
		}
		
		bt1.Run();
		bt2.Run();
		
		// open up both crossings' exits
		local exit = fromCrossing.GetExit(fromDirection);
		AIRail.BuildSignal(exit[0], exit[1], AIRail.SIGNALTYPE_PBS_ONEWAY);
		
		exit = toCrossing.GetExit(toDirection);
		AIRail.BuildSignal(exit[0], exit[1], AIRail.SIGNALTYPE_PBS_ONEWAY);
	}
	
	function Swap(tiles) {
		return [tiles[1], tiles[0]];
	}
	
	function _tostring() {
		return "ConnectCrossing";
	}
}

class ExtendCrossing extends Builder {

	static RAIL_STATION_RADIUS = 4;
	static RAIL_STATION_LENGTH = 8;	// actual building and rails plus room for exit
	static RAIL_STATION_WIDTH = 2;
	
	crossing = null;
	direction = null;
	stations = null;
	network = null;
	
	constructor(crossing, direction, network) {
		Builder.constructor(crossing);
		this.crossing = crossing;
		this.direction = direction;
		this.network = network;
	}
	
	function _tostring() {
		return "ExtendCrossing " + GetLocationString();
	}
	
	function Run() {
		// see if we''ve not already built this direction
		local entrance = world.crossings[crossing].GetEntrance(direction);
		if (AIRail.IsRailTile(entrance[0])) {
			return;
		}
		
		// do the math
		local towns = FindTowns();
		local town = null;
		local stationTile = null;
		for (town = towns.Begin(); towns.HasNext(); town = towns.Next()) {
			stationTile = FindStationSite(town, StationRotationForDirection());
			if (stationTile) break;
		}
		
		if (!stationTile) {
			Error("No towns where we can build a station");
			throw FAILED;
		}
			
		local crossingTile = FindCrossingSite(stationTile);
		
		// do the work
		local subtasks;
		if (crossingTile) {
			local crossingEntranceDirection = InverseDirection(direction);
			local crossingExitDirection = CrossingExitDirection(crossingTile, stationTile);
			
			subtasks = [
				BuildTerminusStation(stationTile, StationRotationForDirection(), network),
				LevelTerrain(crossingTile, Rotation.ROT_0, [-1, -1], [Crossing.WIDTH + 1, Crossing.WIDTH + 1]),
				BuildCrossing(crossingTile, network),
				ConnectCrossing(crossing, direction, crossingTile, crossingEntranceDirection, network),
				ConnectStation(crossingTile, crossingExitDirection, stationTile, network),
				BuildBusStations(stationTile, town),
				BuildTrains(stationTile, network),
			];
		} else {
			subtasks = [
				BuildTerminusStation(stationTile, StationRotationForDirection(), network),
				ConnectStation(crossing, direction, stationTile, network),
				BuildBusStations(stationTile, town),
				BuildTrains(stationTile, network),
			];
		}
		
		tasks.insert(1, TaskList(this, subtasks));
	}
	
	function StationRotationForDirection() {
		switch (direction) {
			case Direction.NE: return Rotation.ROT_270;
			case Direction.SE: return Rotation.ROT_180;
			case Direction.SW: return Rotation.ROT_90;
			case Direction.NW: return Rotation.ROT_0;
			default: throw "invalid direction";
		}
	}
	
	function InverseDirection(direction) {
		switch (direction) {
			case Direction.N: return Direction.S;
			case Direction.E: return Direction.W;
			case Direction.S: return Direction.N;
			case Direction.W: return Direction.E;
			
			case Direction.NE: return Direction.SW;
			case Direction.SE: return Direction.NW;
			case Direction.SW: return Direction.NE;
			case Direction.NW: return Direction.SE;
			default: throw "invalid direction";
		}
	}
	
	function CrossingExitDirection(crossingTile, stationTile) {
		local dx = AIMap.GetTileX(stationTile) - AIMap.GetTileX(crossingTile);
		local dy = AIMap.GetTileY(stationTile) - AIMap.GetTileY(crossingTile);
		
		// leave the new crossing in a direction perpendicular to the one we came in through
		switch (direction) {
			case Direction.NE: return dy > 0 ? Direction.SE : Direction.NW;
			case Direction.SE: return dx > 0 ? Direction.SW : Direction.NE;
			case Direction.SW: return dy > 0 ? Direction.SE : Direction.NW;
			case Direction.NW: return dx > 0 ? Direction.SW : Direction.NE;
			default: throw "invalid direction";
		}
	}
	
	/*
	 * Find a town in the expansion direction, at least half a BLOCK_SIZE away,
	 * in a band BLOCK_SIZE wide.
	 */
	function FindTowns() {
		local towns = AITownList();
		switch (direction) {
			case Direction.NE:
				// negative X
				FilterTowns(towns, crossing, GetXDistance, false, GetYDistance);
				break;
				
			case Direction.SE:
				// positive Y
				FilterTowns(towns, crossing, GetYDistance, true, GetXDistance);
				break;
				
			case Direction.SW:
				// positive X
				FilterTowns(towns, crossing, GetXDistance, true, GetYDistance);
				break;
				
			case Direction.NW:
				// negative Y
				FilterTowns(towns, crossing, GetYDistance, false, GetXDistance);
				break;
			
			default: throw "invalid direction";
		}
		
		if (towns.IsEmpty()) {
			Error("No suitable town");
			throw FAILED;
		}
		
		towns.Valuate(AITown.GetDistanceManhattanToTile, crossing);
		towns.Sort(AIList.SORT_BY_VALUE, true);
		return towns;
	}
	
	function FilterTowns(towns, location, lengthValuator, positive, widthValuator) {
		// remove that are too close or too far
		towns.Valuate(lengthValuator, location);
		if (positive) {
			towns.RemoveBelowValue(BLOCK_SIZE/2);
			towns.RemoveAboveValue(BLOCK_SIZE*2);
		} else {
			towns.RemoveAboveValue(-BLOCK_SIZE/2);
			towns.RemoveBelowValue(-BLOCK_SIZE*2);
		}
		
		// remove towns too far off to the side
		towns.Valuate(widthValuator, location);
		towns.KeepBetweenValue(-BLOCK_SIZE/2, BLOCK_SIZE/2);
	}
	
	function GetXDistance(town, tile) {
		return AIMap.GetTileX(AITown.GetLocation(town)) - AIMap.GetTileX(tile);
	}
	
	function GetYDistance(town, tile) {
		return AIMap.GetTileY(AITown.GetLocation(town)) - AIMap.GetTileY(tile);
	}
	
	function FindStationSite(town, stationRotation) {
		local location = AITown.GetLocation(town);
		
		local area = AITileList();
		SafeAddRectangle(area, location, 20);
		
		// only tiles that "belong" to the town
		area.Valuate(AITile.GetClosestTown)
		area.KeepValue(town);
		
		// room for a station
		area.Valuate(IsBuildableRectangle, stationRotation, [0, 0], [RAIL_STATION_WIDTH, RAIL_STATION_LENGTH], true);
		area.KeepValue(1);
		
		// must accept and produce passengers
		area.Valuate(AITile.GetCargoAcceptance, PAX, 1, 1, RAIL_STATION_RADIUS);
		area.KeepAboveValue(7);
		area.Valuate(AITile.GetCargoProduction, PAX, 1, 1, RAIL_STATION_RADIUS);
		area.KeepAboveValue(7);
		
		// pick the tile closest to the crossing
		area.Valuate(AITile.GetDistanceManhattanToTile, crossing);
		area.KeepBottom(1);
		
		return area.IsEmpty() ? null : area.Begin();
	}
	
	function FindCrossingSite(stationTile) {
		local dx = AIMap.GetTileX(stationTile) - AIMap.GetTileX(crossing);
		local dy = AIMap.GetTileY(stationTile) - AIMap.GetTileY(crossing);
		if (abs(dx) < 2*Crossing.WIDTH || abs(dy) < 2*Crossing.WIDTH) return null;
		
		local centerTile = crossing;
		if (direction == Direction.NE || direction == Direction.SW) {
			centerTile += AIMap.GetTileIndex(dx - Sign(dx) * RAIL_STATION_LENGTH, 0);
		} else {
			centerTile += AIMap.GetTileIndex(0, dy - Sign(dy) * RAIL_STATION_LENGTH);
		}
		
		// find a buildable area closest to ideal tile
		local tiles = AITileList();
		SafeAddRectangle(tiles, centerTile, Crossing.WIDTH);
		tiles.Valuate(IsBuildableRectangle, Rotation.ROT_0, [-2, -2], [Crossing.WIDTH + 2, Crossing.WIDTH + 2], false);
		tiles.KeepValue(1);
		tiles.Valuate(AIMap.DistanceManhattan, centerTile);
		tiles.KeepBottom(1);
		return tiles.IsEmpty() ? null : tiles.Begin();
	}
	
	function IsBuildableRectangle(location, rotation, from, to, mustBeFlat) {
		// check if the area is clear and flat
		// TODO: don't require it to be flat, check if it can be leveled
		local coords = RelativeCoordinates(location, rotation);
		local height = AITile.GetHeight(location);
		for (local x = from[0]; x < to[0]; x++) {
			for (local y = from[1]; y < to[1]; y++) {
				local tile = coords.GetTile([x, y]);
				local flat = AITile.GetHeight(tile) == height && AITile.GetMinHeight(tile) == height && AITile.GetMaxHeight(tile) == height;
				if (!AITile.IsBuildable(tile) || (mustBeFlat && !flat)) {
					return false;
				}
			}
		}
		
		return true;
	}
}

class BuildTrains {
	
	stationTile = null;
	network = null;
	depot = null;
	engine = null;
	
	constructor(stationTile, network) {
		this.stationTile = stationTile;
		this.network = network;
	}
	
	function _tostring() {
		return "BuildTrains";
	}
	
	function Run() {
		local depotList = AIList();
		foreach (depot in network.depots) {
			depotList.AddItem(depot, 0);
		}
		
		depotList.Valuate(AIMap.DistanceManhattan, stationTile);
		depotList.KeepBottom(1);
		if (depotList.IsEmpty()) {
			// nowhere to build trains
			return;
		}
		
		local depot = depotList.Begin();
		
		local from = AIStation.GetStationID(stationTile);
		foreach (to in network.stations) {
			local distance = AIMap.DistanceManhattan(stationTile, AIStation.GetLocation(to));
			local numTrains = network.trains.len();
			local numStations = network.stations.len();
			// build more trains if we have few, or they are long distance
			if (distance > BLOCK_SIZE &&
				numTrains < 30*numStations &&
				(numTrains < 2*numStations || distance > 3*BLOCK_SIZE)) {
				tasks.insert(1, BuildTrain(from, to, depot, network));
			}
		}
	}
	
}

class BuildTrain extends Builder {
	
	static TRAIN_LENGTH = 6;
	
	from = null;
	to = null;
	depot = null;
	network = null;
	train = null;
	
	constructor(from, to, depot, network) {
		this.from = from;
		this.to = to;
		this.depot = depot;
		this.network = network;
		this.train = null;
	}
	
	function _tostring() {
		return "BuildTrain " + GetLocationString(depot);
	}
	
	function Run() {
		if (!train || !AIVehicle.IsValidVehicle(train)) {
			Debug("Building locomotive at " + AIMap.GetTileX(depot) + "," + AIMap.GetTileY(depot));
			train = AIVehicle.BuildVehicle(depot, GetEngine(network.railType));
			CheckError();
		}
		
		local wagonType = GetWagon(PAX, network.railType);
		while (AIVehicle.GetNumWagons(train) < TRAIN_LENGTH) {
			local wagon = AIVehicle.BuildVehicle(depot, wagonType);
			CheckError();
			AIVehicle.MoveWagon(wagon, 0, train, 0);
		}

		Debug("Built train: " + train);
		network.trains.append(train);
		AIOrder.AppendOrder(train, AIStation.GetLocation(from), AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		AIOrder.AppendOrder(train, AIStation.GetLocation(to),   AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		AIVehicle.StartStopVehicle(train);
	}
	
	function GetEngine(railType) {
		local engineList = AIEngineList(AIVehicle.VT_RAIL);
		engineList.Valuate(AIEngine.CanRunOnRail, railType);
		engineList.KeepValue(1);

		//engineList.Valuate(AIEngine.GetReliability);	// TODO: may be better if breakdowns are on
		engineList.Valuate(AIEngine.GetMaxSpeed);

		engineList.KeepTop(1);
		local engine = engineList.Begin();
		//Debug("Picked engine: " + AIEngine.GetName(engine));

		return engine;
	}
	
	function GetWagon(cargoID, railType) {
		local engineList = AIEngineList(AIVehicle.VT_RAIL);
		engineList.Valuate(AIEngine.CanRefitCargo, cargoID);
		engineList.KeepValue(1);

		engineList.Valuate(AIEngine.IsWagon);
		engineList.KeepValue(1);
		
		engineList.Valuate(AIEngine.CanRunOnRail, railType);
		engineList.KeepValue(1);

		engineList.Valuate(AIEngine.GetCapacity)
		engineList.KeepTop(1);
		
		local engine = engineList.Begin();
		//Debug("Picked cart for cargo " + AICargo.GetCargoLabel(cargoID) + ": " + AIEngine.GetName(engine));

		return engine;
	}
}
		

class LevelTerrain extends Builder {
	
	location = null;
	from = null;
	to = null;
	
	constructor(location, rotation, from, to) {
		Builder.constructor(location, rotation);
		this.from = from;
		this.to = to;
	}
	
	function Run() {
		// TODO: this levels the area between the north corners of the resulting tiles
		// so due to rotation, we may be one tile short
		if (!AITile.LevelTiles(GetTile(from), GetTile(to))) {
			CheckError();
		}
	}
	
	function _tostring() {
		return "LevelTerrain";
	}
	
}
