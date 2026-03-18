-- flurries for iii - boreal ground
print("flurries v0.2")

-- editable parameters
local internal_clock_bpm = 120 -- set starting bpm for internal clock
local run_clock = true -- override: stops listening to all clocks
local first_step = 1 -- first step of loop
local last_step = 16 -- last step of loop

-- starting parameters
local clock_led = 0
local midi_ppqn = 0
local midi_sync = false
local forwards = true
local current_step = first_step
local buttons_held = 0
local temp_first_step = 0
local temp_last_step = 0

-- MIDI constants
local MIDI_CLOCK = 248
local MIDI_START = 250
local MIDI_STOP = 252

-- redraw grid leds
function redraw_grid()
    grid_led_all(0)
    if run_clock then
        -- led 1,1 blink on clock running
        grid_led(1, 1, clock_led * 15)
    else
        -- led 1,1 lit when run_clock is false
        grid_led(1, 1, 15)
    end

    -- light leds within active loop
    if first_step <= last_step then
        for i = first_step, last_step do
            grid_led(i, 2, 4)
        end
    elseif first_step > last_step then
        for i = first_step, last_step, -1 do
            grid_led(i, 2, 4)
        end
    end

    -- light led for current_step
    if current_step >= 1 and current_step <= 16 then
        grid_led(current_step, 2, 15)
    end

    grid_refresh()
end

-- clock tick function
function tick()
    -- update state of clock_led
    clock_led = 1 - clock_led

    -- check direction of loop
    if forwards then
        -- forward loop
        if current_step < last_step then
            current_step = current_step + 1
        else
            current_step = first_step
        end
    else
        -- backwards loop
        if current_step > last_step then
            current_step = current_step - 1
        else
            current_step = first_step
        end
    end

    -- add further on-tick functionality here

    redraw_grid()
end

-- check direction of loop
function check_direction()
    if first_step > last_step then
        forwards = false
    else
        forwards = true
    end
end

-- initialise internal clock
local internal_clock = metro.init(tick, 30 / internal_clock_bpm)

-- run internal clock on script launch
check_direction()
internal_clock:start()
redraw_grid()

-- print script start state
print("internal clock bpm: " .. tostring(internal_clock_bpm))
print("midi sync: " .. tostring(midi_sync))
print("clock running: " .. tostring(run_clock))

-- grid button event handling
function event_grid(x, y, z)
    -- menu row: row 1
    if y == 1 then
        if x == 1 and z == 1 then
            -- if button 1,1 is pressed: toggles run_clock override
            run_clock = not run_clock
            print("clock running: " .. tostring(run_clock))

            if not run_clock then
                internal_clock:stop()
            elseif not midi_sync then
                internal_clock:start()
            end

            -- run redraw_grid() function on button-press
            redraw_grid()
        end
    elseif y == 2 then
        -- if two buttons are held, update first_step and last_step on release
        if z == 1 then
            -- button pressed
            buttons_held = buttons_held + 1

            if buttons_held == 1 then
                temp_first_step = x
            elseif buttons_held == 2 then
                temp_last_step = x
            end
        else
            -- button released
            buttons_held = buttons_held - 1

            if buttons_held == 0 and temp_first_step > 0 and temp_last_step > 0 then
                first_step = temp_first_step
                last_step = temp_last_step
                check_direction()

                -- only reset current_step if it is outside of new loop
                if forwards then
                    if current_step < first_step or current_step > last_step then
                        current_step = first_step
                    end
                else
                    if current_step > first_step or current_step < last_step then
                        current_step = first_step
                    end
                end

                temp_first_step = 0
                temp_last_step = 0
                redraw_grid()
            end
        end
    end
end

-- midi event handling
function event_midi(d1, d2, d3)

    -- midi transport message handling
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

    -- midi note / CC handling
    midi_message(d1, d2, d3)
end

function midi_message(d1, d2, d3)
    -- add further midi note / CC handling here
end
