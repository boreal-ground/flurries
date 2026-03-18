-- flurries for iii - boreal ground
print("flurries v0.4")

-- editable parameters
local internal_clock_bpm = 120 -- set starting bpm for internal clock
local run_clock = true -- clock override: stops listening to all clocks if false
local loop_start = 1 -- first step of loop
local loop_end = 16 -- last step of loop

-- starting parameters
local clock_led = 0
local midi_ppqn = 0
local midi_sync = false
local forwards = true
local current_step = loop_start
local buttons_held = 0
local temp_loop_start = 0
local temp_loop_end = 0

-- MIDI constants
local MIDI_CLOCK = 248
local MIDI_START = 250
local MIDI_STOP = 252

-- FUNCTIONS

-- redraw grid leds
function redraw_grid()
    grid_led_all(0)

    -- clock led
    if run_clock then
        -- led 1,1 blink on clock running
        grid_led(1, 1, clock_led * 15)
    else
        -- led 1,1 lit when run_clock is false
        grid_led(1, 1, 15)
    end

    -- light leds within active loop
    local step_min = math.min(loop_start, loop_end)
    local step_max = math.max(loop_start, loop_end)
    for i = step_min, step_max do
        grid_led(i, 2, 4)
    end

    -- light led for current_step
    if current_step >= 1 and current_step <= 16 then
        grid_led(current_step, 2, 15)
    end

    -- light held start/end button leds for new loop
    if temp_loop_start ~= 0 then
        grid_led(temp_loop_start, 2, 15)
    end
    if temp_loop_end ~= 0 then
        grid_led(temp_loop_end, 2, 15)
    end

    grid_refresh()
end

-- check direction of loop
function check_direction()
    forwards = loop_start <= loop_end
end

-- clock tick function
function tick()
    -- update state of clock_led
    clock_led = 1 - clock_led

    -- loop wraparound logic
    if forwards then
        -- forwards
        current_step = current_step + 1
        if current_step > loop_end then
            current_step = loop_start
        end
    else
        -- backwards
        current_step = current_step - 1
        if current_step < loop_end then
            current_step = loop_start
        end
    end

    -- add further on-tick functionality here

    redraw_grid()
end

-- MAIN SCRIPT

-- initialise internal clock
local internal_clock = metro.init(tick, 30 / internal_clock_bpm)

-- run internal clock on script launch
check_direction()
if run_clock then
    internal_clock:start()
end
redraw_grid()

-- print script start state
print("internal clock bpm: " .. tostring(internal_clock_bpm))
print("midi sync: " .. tostring(midi_sync))
print("clock running: " .. tostring(run_clock))

-- grid button event handling
function event_grid(x, y, z)
    if y == 1 then
        -- menu row: row 1

        if x == 1 and z == 1 then

            -- if button 1,1 is pressed: toggles run_clock override
            run_clock = not run_clock
            print("clock running: " .. tostring(run_clock))

            if not run_clock then
                internal_clock:stop()
            elseif not midi_sync then
                internal_clock:start()
            end
            redraw_grid()
        end

    elseif y == 2 then
        -- loop row: row 2

        -- if two buttons are held, update loop_start and loop_end on release
        if z == 1 then
            -- button pressed
            buttons_held = math.min(buttons_held + 1, 2)

            if buttons_held == 1 then
                temp_loop_start = x
                temp_loop_end = x
            elseif buttons_held == 2 then
                temp_loop_end = x
            end
            redraw_grid()
        else
            -- button released
            buttons_held = math.max(buttons_held - 1, 0)
            -- redraw_grid()

            if buttons_held == 0 and temp_loop_start > 0 and temp_loop_end > 0 then
                loop_start = temp_loop_start
                loop_end = temp_loop_end
                check_direction()

                -- only reset current_step if it is outside of new loop
                if forwards then
                    if current_step < loop_start or current_step > loop_end then
                        current_step = loop_start
                    end
                else
                    if current_step > loop_start or current_step < loop_end then
                        current_step = loop_start
                    end
                end

                print("loop start: " .. temp_loop_start .. " | loop end: " .. temp_loop_end)
                temp_loop_start = 0
                temp_loop_end = 0
                redraw_grid()
            end
        end
    end
end

-- midi in event handling
function event_midi(d1, d2, d3)

    -- midi in transport message handling
    if d1 == MIDI_STOP then
        midi_sync = false
        print("midi sync: " .. tostring(midi_sync))
        if run_clock then
            internal_clock:start()
        end
        return

    elseif d1 == MIDI_START then
        -- ignore midi start when run_clock is false
        if run_clock then
            midi_sync = true
            print("midi sync: " .. tostring(midi_sync))
            internal_clock:stop()
            midi_ppqn = 0
            tick()
        end
        return
    elseif d1 == MIDI_CLOCK then
        -- ignore midi clock when run_clock is false
        if run_clock then
            midi_sync = true
            midi_ppqn = (midi_ppqn + 1) % 12
            if midi_ppqn == 0 then
                tick()
            end
        end
        return
    end

    -- midi in note / CC handling
    midi_message(d1, d2, d3)
end

function midi_message(d1, d2, d3)
    -- add further midi note / CC handling here
end
