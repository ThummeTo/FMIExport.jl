#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# equations are a modified version of the Modelica reference FMUs:
# https://github.com/modelica/Reference-FMUs/blob/main/BouncingBall/model.c

using FMIExport
using FMIExport.FMIBase.FMICore: fmi2True, fmi2False, fmi2Integer

# a minimum height to reset the ball after event
EPS = 1e-8

# ball position, velocity (initial)
DEFAULT_X0 = [1.0, 0.0]
# ball mass, ball radius, ball collision damping, ball minimum velocity, gravity constant 
DEFAULT_PARAMS = [1.0, 0.1, 0.9, 1e-3, 9.81]

FMU_FCT_INIT = function ()

    sticking = fmi2False
    counter = fmi2Integer(0)

    s = DEFAULT_X0[1]         # ball position
    v = DEFAULT_X0[2]         # ball velocity
    a = 0.0                   # ball acceleration

    t = 0.0
    x_c = [s, v]
    ẋ_c = [v, a]
    x_d = [sticking, counter]
    u = []
    p = DEFAULT_PARAMS

    return (t, x_c, ẋ_c, x_d, u, p)
end

FMU_FCT_EVALUATE = function (t, x_c, ẋ_c, x_d, u, p, eventMode)
    m, r, d, v_min, g = p
    s, v = x_c
    sticking, counter = x_d
    _, a = ẋ_c

    if sticking == fmi2True
        a = 0.0
    elseif sticking == fmi2False

        if eventMode
            h = s - r
            if h <= 0 && v < 0
                s = r + EPS # so that indicator is not triggered again
                v = -v * d
                counter = fmi2Integer(counter + 1)

                # stop bouncing to prevent high frequency bouncing (and maybe tunneling the floor)
                if abs(v) < v_min
                    sticking = fmi2True
                    v = 0.0
                end
            end
        end

        a = (m * -g) / m     # the system's physical equation (a little longer than necessary)
    else
        @error "Unknown value for `sticking` == $(sticking)."
        return (x_c, ẋ_c, x_d, p)
    end

    # Todo: Remove these allocations. Make it inplace.
    x_c = [s, v]
    ẋ_c = [v, a]
    x_d = [sticking, counter]
    p = [m, r, d, v_min, g]

    return (x_c, ẋ_c, x_d, p)
end

FMU_FCT_OUTPUT = function (t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking, counter = x_d

    y = [s, v]

    return y
end

FMU_FCT_EVENT = function (t, x_c, ẋ_c, x_d, u, p)
    m, r, d, v_min, g = p
    s, v = x_c
    _, a = ẋ_c
    sticking, counter = x_d

    # helpers
    z1 = 0.0 # first event indicator
    h = s - r # ball height

    if sticking == fmi2True
        z1 = 1.0            # event 1: ball stay-on-ground
    else
        if h > -EPS && h <= 0 && v > 0
            z1 = -EPS
        else
            z1 = h
        end
    end

    z = [z1]

    return z
end

# this function is called, as soon as the DLL is loaded and Julia is initialized 
# must return a FMU2-instance to work with
FMIBUILD_CONSTRUCTOR = function (resPath = "")
    fmu = fmi2CreateSimple(
        initializationFct = FMU_FCT_INIT,
        evaluationFct = FMU_FCT_EVALUATE,
        outputFct = FMU_FCT_OUTPUT,
        eventFct = FMU_FCT_EVENT,
    )

    fmu.modelDescription.modelName = "BouncingBall"

    # modes 
    fmi2ModelDescriptionAddModelExchange(fmu.modelDescription, "BouncingBall")

    # states [2]
    fmi2AddStateAndDerivative(
        fmu,
        "ball.s";
        stateStart = DEFAULT_X0[1],
        stateDescr = "Absolute position of ball center of mass",
        derivativeDescr = "Absolute velocity of ball center of mass",
    )
    fmi2AddStateAndDerivative(
        fmu,
        "ball.v";
        stateStart = DEFAULT_X0[2],
        stateDescr = "Absolute velocity of ball center of mass",
        derivativeDescr = "Absolute acceleration of ball center of mass",
    )

    # discrete state [2]
    fmi2AddIntegerDiscreteState(
        fmu,
        "sticking";
        description = "Indicator (boolean) if the mass is sticking on the ground, as soon as abs(v) < v_min",
    )
    fmi2AddIntegerDiscreteState(
        fmu,
        "counter";
        description = "Number of collision with the floor.",
    )

    # outputs [2]
    fmi2AddRealOutput(
        fmu,
        "ball.s_out";
        description = "Absolute position of ball center of mass",
    )
    fmi2AddRealOutput(
        fmu,
        "ball.v_out";
        description = "Absolute velocity of ball center of mass",
    )

    # parameters [5]
    fmi2AddRealParameter(fmu, "m"; start = DEFAULT_PARAMS[1], description = "Mass of ball")
    fmi2AddRealParameter(
        fmu,
        "r";
        start = DEFAULT_PARAMS[2],
        description = "Radius of ball",
    )
    fmi2AddRealParameter(
        fmu,
        "d";
        start = DEFAULT_PARAMS[3],
        description = "Collision damping constant (velocity fraction after hitting the ground)",
    )
    fmi2AddRealParameter(
        fmu,
        "v_min";
        start = DEFAULT_PARAMS[4],
        description = "Minimal ball velocity to enter on-ground-state",
    )
    fmi2AddRealParameter(
        fmu,
        "g";
        start = DEFAULT_PARAMS[5],
        description = "Gravity constant",
    )

    fmi2AddEventIndicator(fmu)

    return fmu
end

### FMIBUILD_NO_EXPORT_BEGIN ###
# The line above is a start-marker for excluded code for the FMU compilation process!

fmu = FMIBUILD_CONSTRUCTOR()

# first, we try to simulate the FMU before ExternalFMIExportTesting
# this is not required for export but a good idea anyway: 
# the export takes a long time and exporting a possibly broken FMU does not help anyone
using FMI, DifferentialEquations
fmu.executionConfig.loggingOn = true
solution = simulate(fmu, (0.0, 3.0); recordValues = ["sticking", "counter"])
# using Plots
# plot(solution)
# fmu.modelDescription.discreteStateValueReferences
# fmu.modelDescription.outputValueReferences

tmpDir = mktempdir(; prefix = "fmibuildjl_test_", cleanup = false)
@info "Saving example files at: $(tmpDir)"
fmu_save_path = joinpath(tmpDir, "BouncingBall.fmu")

# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because FMIBuild cannot execute itself (but it is able to build)
using FMIBuild: saveFMU
# this must be excluded during export -done by FMIBUILD_NO_EXPORT marker-, because saveFMU would start an infinite build loop with itself
saveFMU(fmu, fmu_save_path; debug = true, compress = false)    # (debug=true allows debug messages, but is slow during execution!)

# The following line is a end-marker for excluded code for the FMU compilation process!
### FMIBUILD_NO_EXPORT_END ###
