import carla

param map = localPath('../Unreal/CarlaUE4/Content/Carla/Maps/OpenDrive/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

## CONSTANTS
EGO_MODEL = "vehicle.lincoln.mkz_2017"
EGO_SPEED = 12
EGO_BRAKING_THRESHOLD = 12

LEAD_CAR_SPEED = 10
LEADCAR_BRAKING_THRESHOLD = 10

BRAKE_ACTION = 1.0

PERMITTED_ADV_MODELS = [
  "vehicle.audi.tt", 
  "vehicle.audi.etron", 
  "vehicle.chevrolet.impala", 
  "vehicle.dodge.charger_2020", 
  "vehicle.dodge.charger_police", 
  #"vehicle.dorge.charger_police_2020",
  "vehicle.ford.crown",
  "vehicle.ford.mustang", 
  "vehicle.lincoln.mkz_2017", 
  "vehicle.lincoln.mkz_2020", 
  "vehicle.nissan.patrol_2021",
  "vehicle.mercedes.coupe_2020",
  "vehicle.mini.cooper_s_2021",
  "vehicle.tesla.model3",
  "vehicle.carlamotors.firetruck",
  "vehicle.tesla.cybertruck",
  "vehicle.ford.ambulance",
  "vehicle.mercedes.sprinter",
  "vehicle.volkswagen.t2_2021",
  "vehicle.mitsubishi.fusorosa",
  "vehicle.harley-davidson.low_rider",
  "vehicle.kawasaki.ninja",
  "vehicle.yamaha.yzf"
  ]

# M_CarLightsGlass_Master

PERMITTED_LIGHT_STATES = [
    carla.VehicleLightState.NONE,
    carla.VehicleLightState.LeftBlinker,
    carla.VehicleLightState.RightBlinker,
    carla.VehicleLightState.Brake,
    carla.VehicleLightState.LeftBlinker | carla.VehicleLightState.RightBlinker,
    carla.VehicleLightState.LeftBlinker | carla.VehicleLightState.Brake,
    carla.VehicleLightState.RightBlinker | carla.VehicleLightState.Brake,
    carla.VehicleLightState.LeftBlinker | carla.VehicleLightState.RightBlinker | carla.VehicleLightState.Brake,
]

## DEFINING BEHAVIORS
# EGO BEHAVIOR: Follow lane, and brake after passing a threshold distance to the leading car
behavior EgoBehavior(speed):
    try:
        do FollowLaneBehavior(speed)

    interrupt when withinDistanceToAnyCars(self, EGO_BRAKING_THRESHOLD):
        take SetBrakeAction(BRAKE_ACTION)

# LEAD CAR BEHAVIOR: Follow lane, and brake after passing a threshold distance to obstacle
behavior LeadingCarBehavior(speed, light_state):
    try: 
        take SetVehicleLightStateAction(carla.VehicleLightState(light_state))
        do FollowLaneBehavior(speed)

    interrupt when withinDistanceToAnyObjs(self, LEADCAR_BRAKING_THRESHOLD):
        take SetBrakeAction(BRAKE_ACTION)

## DEFINING SPATIAL RELATIONS

lane = Uniform(*network.lanes)

obstacle = new Trash on lane.centerline

leadCarBlueprint = Uniform(*PERMITTED_ADV_MODELS)

leadCarLightState = Uniform(*PERMITTED_LIGHT_STATES)

leadCar = new Car following roadDirection from obstacle for Range(-50, -30),
        with blueprint leadCarBlueprint,
        with behavior LeadingCarBehavior(LEAD_CAR_SPEED, leadCarLightState),
        facing directly toward obstacle

ego = new Car following roadDirection from leadCar for Range(-15, -10),
        with blueprint EGO_MODEL,
        with behavior EgoBehavior(EGO_SPEED),
        facing directly toward leadCar


require (distance to intersection) > 80
terminate when (ego.speed < 0.1 and (distance to obstacle) < 30) or ((distance to leadCar) > 30)