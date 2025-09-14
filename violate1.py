# Import necessary libraries.
import omni.usd
import omni.kit.app
from pxr import Gf, UsdGeom, UsdPhysics, UsdLux

# --- User Settings (Modify these to match your scene) ---

# 1. Define light paths
INITIAL_YELLOW_BLINK_PATHS = [
    "/World/traffic_light_03/yellow3",
    "/World/traffic_light_01/yellow1"
]

NORTH_SOUTH_LIGHTS = {
    "red": ["/World/traffic_light_04/red4", "/World/traffic_light_02/red2"],
    "yellow": ["/World/traffic_light_04/yellow4", "/World/traffic_light_02/yellow2"],
    "green": ["/World/traffic_light_04/green4", "/World/traffic_light_02/green2"],
}
EAST_WEST_LIGHTS = {
    "red": ["/World/traffic_light_01/red1", "/World/traffic_light_03/red3"],
    "yellow": ["/World/traffic_light_01/yellow1", "/World/traffic_light_03/yellow3"],
    "green": ["/World/traffic_light_01/green1", "/World/traffic_light_03/green3"],
}

# 2. Define light paths for pedestrians
#    These lights should be green when the parallel vehicle traffic is red.
NS_PEDESTRIAN_LIGHTS = {
    "red": [
        "/World/traffic_light_01/red1_2", 
        "/World/traffic_light_02/red2_1",
        "/World/traffic_light_03/red3_2", # Add path for the 3rd red light
        "/World/traffic_light_04/red4_1"  # Add path for the 4th red light
    ],
    "green": [
        "/World/traffic_light_01/green1_2", 
        "/World/traffic_light_02/green2_1",
        "/World/traffic_light_03/green3_2", # Add path for the 3rd green light
        "/World/traffic_light_04/green4_1"  # Add path for the 4th green light
    ]
}
EW_PEDESTRIAN_LIGHTS = {
    "red": [
        "/World/traffic_light_01/red1_1", 
        "/World/traffic_light_04/red4_2",
        "/World/traffic_light_02/red2_2", # Add path for the 3rd red light
        "/World/traffic_light_03/red3_1"  # Add path for the 4th red light
    ],
    "green": [
        "/World/traffic_light_01/green1_1", 
        "/World/traffic_light_04/green4_2",
        "/World/traffic_light_02/green2_2", # Add path for the 3rd green light
        "/World/traffic_light_03/green3_1"  # Add path for the 4th green light
    ]
}

# 3. Define vehicles with specific directions
A_VALUE = 1.5
VEHICLES_TO_CONTROL = [
    {
        "name": "Vehicle_2",
        "prim_path": "/World/vehicle2/basic_vehicle_m/WizardVehicle1/Vehicle",
        "direction": "N->S", 
        "drive_velocity":  Gf.Vec3f(-10.0, 1.5, 0.0),
        "behavior": "obey"
    },
    {
        "name": "Vehicle_3",
        "prim_path": "/World/vehicle3/basic_vehicle_m/WizardVehicle1/Vehicle",
        "direction": "W->E", 
        "drive_velocity": Gf.Vec3f(-3.0, -10.0, 0.0),
        "behavior": "obey",
        "timed_behaviors": [
            { "time": 3.0, "new_velocity": Gf.Vec3f(0.0, 0.0, 0.0) },
            { "time": 6.0, "new_velocity": Gf.Vec3f(-3.0, -10.0, 0.0) },
            { "time": 8.2, "new_velocity": Gf.Vec3f(-0.6, -9.5, 0.0) }
        ]
    },
    {
        "name": "Vehicle_4",
        "prim_path": "/World/vehicle4/basic_vehicle_m/WizardVehicle1/Vehicle",
        "direction": "E->W", 
        "drive_velocity": Gf.Vec3f(1, 10.0, 0.0),
        "behavior": "obey",
        "timed_behaviors": [
            { "time": 3.0, "new_velocity": Gf.Vec3f(0.0, 0.0, 0.0) },
            { "time": 6.0, "new_velocity": Gf.Vec3f(1.0, 10.0, 0.0) },
            { "time": 9.4, "new_velocity": Gf.Vec3f(3.3, 14.0, 0.0) }
        ]
    },
    {
        "name": "bluecar_1",
        "prim_path": "/World/bluecar1/Meshes/Sketchfab_model/_fc247d9258a4831b3027384b76cddea_fbx/RootNode", 
        "direction": "N->S",
        "drive_velocity": Gf.Vec3f(-20.0, 3.0, 0.0),
        "behavior": "obey" 
    },
    {
        "name": "greencar_1",
        "prim_path": "/World/greencar1/Meshes/Sketchfab_model/root",
        "direction": "N->S",
        "drive_velocity": Gf.Vec3f(-15.0, 2.25, 0.0),
        "behavior": "obey" 
    },
    {
        "name": "blackcar_1",
        "prim_path": "/World/blackcar1/Meshes/Sketchfab_model/mesh_fbx/RootNode", 
        "direction": "E->W",
        "drive_velocity": Gf.Vec3f(-3.2, -13.2, 0.0),
        "behavior": "obey",
        "timed_behaviors": [
            { "time": 3.0, "new_velocity": Gf.Vec3f(0.0, 0.0, 0.0) },
            { "time": 6.0, "new_velocity": Gf.Vec3f(-3.2, -13.2, 0.0) },
            { "time": 8.1, "new_velocity": Gf.Vec3f(-0.9, -13.0, 0.0) }
        ]
    },
    {
        "name": "sedan",
        "prim_path": "/World/sedan/Meshes/Sketchfab_model", 
        "direction": "S->N",
        "drive_velocity": Gf.Vec3f(12.0, -1.8, 0.0),
        "behavior": "obey" 
    },
    {
        "name": "redcar_1",
        "prim_path": "/World/red_car/Meshes/Sketchfab_model",
        "direction": "E->W",
        "drive_velocity": Gf.Vec3f(1.5, 15.0, 0.0),
        "behavior": "obey", 
        "timed_behaviors":[
            { "time": 3.0, "new_velocity": Gf.Vec3f(0.0, 0.0, 0.0) },
            { "time": 6.0, "new_velocity": Gf.Vec3f(1.5, 15.0, 0.0) },
            { "time": 8.7, "new_velocity": Gf.Vec3f(3.4, 14.0, 0.0) }
        ]
    },
    # --- ▼▼▼ Violator Vehicles ▼▼▼ ---
    {
        "name": "Vehicle_1",
        "prim_path": "/World/vehicle1/basic_vehicle_m/WizardVehicle1/Vehicle",
        "direction": "S->N",
        "drive_velocity": Gf.Vec3f(6.67 * A_VALUE, -A_VALUE, 0.0),
        "behavior": "obey" 
    }
]

# 4. Define pedestrians to control
PEDESTRIANS_TO_CONTROL = [
    {
        "name": "Running_Man_1",
        "prim_path":"/World/run",
        "end_frame": 133
    }
]
STOP_VELOCITY = Gf.Vec3f(0.0, 0.0, 0.0)
SLOW_DOWN_FACTOR = 0.5

# 5. Set signal durations
GREEN_DURATION_S = 15
YELLOW_DURATION_S = 1
ON_INTENSITY = 50000.0
OFF_INTENSITY = 0.0
BLINK_INTENSITY = 500000.0 # Intensity for blinking lights

# --- Main Logic ---

class IntersectionController:
    def __init__(self):
        self.stage = omni.usd.get_context().get_stage()
        self.ns_lights = self._get_prims(NORTH_SOUTH_LIGHTS)
        self.ew_lights = self._get_prims(EAST_WEST_LIGHTS)
        self.ns_ped_lights = self._get_prims(NS_PEDESTRIAN_LIGHTS)
        self.ew_ped_lights = self._get_prims(EW_PEDESTRIAN_LIGHTS)
        
        self.vehicles = []
        for v_info in VEHICLES_TO_CONTROL:
            prim = self.stage.GetPrimAtPath(v_info["prim_path"])
            if prim and prim.IsValid():
                self.vehicles.append({
                    "info": v_info, "prim": prim,
                    "rigid_body": UsdPhysics.RigidBodyAPI.Get(self.stage, prim.GetPath()),
                    "has_started_moving": False, "time_since_move_start": 0.0 
                })
            else:
                print(f"Warning: Vehicle prim not found at path: {v_info['prim_path']}")

        self.pedestrians = []
        self.timeline = omni.timeline.get_timeline_interface()
        for p_info in PEDESTRIANS_TO_CONTROL:
            prim = self.stage.GetPrimAtPath(p_info["prim_path"])
            if prim and prim.IsValid():
                self.pedestrians.append({"info": p_info, "prim": prim, "is_hidden": False})
            else:
                print(f"Warning: Pedestrian prim not found at path: {p_info['prim_path']}")

        self.phase_duration = GREEN_DURATION_S + YELLOW_DURATION_S
        self.total_cycle_duration = self.phase_duration * 2
        
        self.time_elapsed = self.phase_duration 
        self.ns_signal_state = "red"
        self.ew_signal_state = "green"
        
        # Variable to track total time for initial blinking effect
        self.total_time_since_start = 0.0

        self.subscription = None
        self.setup_update_callback()
        print("Intersection control system started. EW direction starts with Green.")
        
    def _get_prims(self, path_dict):
        prim_dict = {}
        for color, paths in path_dict.items():
            prim_dict[color] = [self.stage.GetPrimAtPath(p) for p in paths]
        return prim_dict

    def _set_light_intensity(self, prim, intensity):
        """Helper function to set light intensity."""
        if prim and prim.IsValid():
            # Check for API and apply if necessary, but focus on the attribute
            if not prim.HasAPI(UsdLux.LightAPI):
                UsdLux.LightAPI.Apply(prim)
            light_api = UsdLux.LightAPI(prim)
            light_api.GetIntensityAttr().Set(intensity)

    def _set_group_lights(self, light_group, active_color):
        if not light_group: return
        for color, prims in light_group.items():
            intensity = ON_INTENSITY if color == active_color else OFF_INTENSITY
            for prim in prims:
                self._set_light_intensity(prim, intensity)

    def _handle_initial_blinking(self, dt):
        """Makes specific yellow lights blink for a short period at the beginning."""
        self.total_time_since_start += dt
        
        start_time = 3.0  # Start after 3 seconds
        duration = 3.0    # Last for 3 seconds
        interval = 0.5    # Blink at 0.5-second intervals
        
        # Check if we are within the blinking time window
        if start_time <= self.total_time_since_start <= start_time + duration:
            time_into_blink = self.total_time_since_start - start_time
            # Determine if the light should be ON or OFF based on the interval
            num_intervals_passed = int(time_into_blink / interval)
            is_on = (num_intervals_passed % 2 == 0)
            
            intensity = BLINK_INTENSITY if is_on else OFF_INTENSITY
            
            for path in INITIAL_YELLOW_BLINK_PATHS:
                prim = self.stage.GetPrimAtPath(path)
                self._set_light_intensity(prim, intensity)

    def _control_vehicles(self, dt):
        for vehicle in self.vehicles:
            if not vehicle["rigid_body"]:
                continue
            
            vehicle_info = vehicle["info"]
            
            signal_group = "NS" if "N" in vehicle_info["direction"] or "S" in vehicle_info["direction"] else "EW"
            current_signal_state = self.ns_signal_state if signal_group == "NS" else self.ew_signal_state

            if current_signal_state == "green":
                # ▼▼▼ All 'green' related logic goes inside this block ▼▼▼
                vehicle["time_since_move_start"] += dt
                
                # 1. First, set the default drive velocity.
                target_velocity = vehicle_info["drive_velocity"]
                
                # 2. Check for timed behaviors and override the velocity if they exist.
                timed_behaviors = vehicle_info.get("timed_behaviors")
                if timed_behaviors:
                    for behavior in timed_behaviors:
                        if vehicle["time_since_move_start"] >= behavior["time"]:
                            target_velocity = behavior["new_velocity"]
                
                # 3. Finally, apply the calculated velocity.
                vehicle["rigid_body"].GetVelocityAttr().Set(target_velocity)
                # ▲▲▲ End of 'green' signal processing ▲▲▲

            elif current_signal_state == "yellow":
                slow_velocity = vehicle_info["drive_velocity"] * SLOW_DOWN_FACTOR
                vehicle["rigid_body"].GetVelocityAttr().Set(slow_velocity)

            else:  # "red"
                vehicle["rigid_body"].GetVelocityAttr().Set(STOP_VELOCITY)
                vehicle["time_since_move_start"] = 0.0

    def _control_pedestrians(self, current_frame):
        for ped in self.pedestrians:
            if not ped["is_hidden"] and current_frame >= ped["info"]["end_frame"]:
                imageable = UsdGeom.Imageable(ped["prim"])
                imageable.MakeInvisible()
                ped["is_hidden"] = True
                print(f"Pedestrian '{ped['info']['name']}' reached end frame and is now hidden.")

    def setup_update_callback(self):
        stream = omni.kit.app.get_app().get_update_event_stream()
        self.subscription = stream.create_subscription_to_pop(
            self.on_update, name="intersection_controller"
        )

    def on_update(self, e):
        dt = e.payload.get("dt", 0.0)
        if dt == 0.0: return

        current_frame = self.timeline.get_current_time() * self.timeline.get_time_codes_per_seconds()
        
        # 1. Set the default state for all traffic lights based on the internal timer.
        self.time_elapsed += dt
        if self.time_elapsed >= self.total_cycle_duration:
            self.time_elapsed -= self.total_cycle_duration

        if 0 <= self.time_elapsed < GREEN_DURATION_S:
            self.ns_signal_state, self.ew_signal_state = "green", "red"
            self._set_group_lights(self.ns_lights, "green")
            self._set_group_lights(self.ew_lights, "red")
            self._set_group_lights(self.ns_ped_lights, "green")
            self._set_group_lights(self.ew_ped_lights, "red")
        elif GREEN_DURATION_S <= self.time_elapsed < self.phase_duration:
            self.ns_signal_state, self.ew_signal_state = "yellow", "red"
            self._set_group_lights(self.ns_lights, "yellow")
            self._set_group_lights(self.ew_lights, "red")
            self._set_group_lights(self.ns_ped_lights, "green") 
            self._set_group_lights(self.ew_ped_lights, "red")
        elif self.phase_duration <= self.time_elapsed < self.phase_duration + GREEN_DURATION_S:
            self.ns_signal_state, self.ew_signal_state = "red", "green"
            self._set_group_lights(self.ns_lights, "red")
            self._set_group_lights(self.ew_lights, "green")
            self._set_group_lights(self.ns_ped_lights, "red")
            self._set_group_lights(self.ew_ped_lights, "green")
        else: # YELLOW FOR EW
            self.ns_signal_state, self.ew_signal_state = "red", "yellow"
            self._set_group_lights(self.ns_lights, "red")
            self._set_group_lights(self.ew_lights, "yellow")
            self._set_group_lights(self.ns_ped_lights, "red")
            self._set_group_lights(self.ew_ped_lights, "green")
        
        # 2. Handle the initial blinking, which will override the lights set above if active.
        self._handle_initial_blinking(dt)

        # 3. Control vehicles based on the current signal state.
        self._control_vehicles(dt)

        # 4. Control pedestrians.
        self._control_pedestrians(current_frame)

    def cleanup(self):
        self.subscription = None
        self._set_group_lights(self.ns_lights, "off")
        self._set_group_lights(self.ew_lights, "off")
        self._set_group_lights(self.ns_ped_lights, "off")
        self._set_group_lights(self.ew_ped_lights, "off")
        
        for ped in self.pedestrians:
            if ped["prim"] and ped["prim"].IsValid():
                imageable = UsdGeom.Imageable(ped["prim"])
                imageable.MakeVisible()

        for vehicle in self.vehicles:
            if vehicle["rigid_body"]:
                vehicle["rigid_body"].GetVelocityAttr().Set(STOP_VELOCITY)
        
        print("Intersection control system stopped.")

# --- Script Execution ---
# Cleanup previous instance if it exists
if "intersection_instance" in globals() and intersection_instance:
    intersection_instance.cleanup()
    del intersection_instance

intersection_instance = IntersectionController()