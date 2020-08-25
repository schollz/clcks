-- xxx v0.1
-- time accessibility adjuster
--
-- llllllll.co/t/xxx
--
--
--
--    ▼ instructions below ▼
--
--
-- hold K1 & press K2 to record,

state_activated=false
state_current_time=0
state_repeat_number=0
state_current_position=0

flag_update_screen=false

param_loop_length=0.5 -- seconds
param_repeats=-1 -- number of repeats
param_final_rate=1
param_final_level=1
param_monitor=1

const_time_per_refresh=0.1

function init()
  audio.comp_mix(1) -- turn on compressor
  audio.level_adc_cut(1) -- send audio input to softcut input
  audio.level_monitor(1)
  
  -- initialize softcut
  softcut.buffer_clear()
  softcut.enable(1,1)
  softcut.level(1,1)
  softcut.buffer(1,1)
  softcut.loop(1,1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,300)
  softcut.position(1,1)
  softcut.play(1,1)
  softcut.rate_slew_time(1,0)
  softcut.level_slew_time(1,0)
  softcut.pan_slew_time(1,0)
  softcut.rec_level(1,1.0)
  softcut.pre_level(1,0.0)
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,1,1.0)
  softcut.rec(1,1) -- always be recording
  
  timer=metro.init()
  timer.time=const_time_per_refresh
  timer.count=-1
  timer.event=timer_update
  timer:start()
  
  -- POSITION POLL
  softcut.phase_quant(1,0.025)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end

function update_positions(i,x)
  state_current_position=x
end

function dump(o)
  if type(o)=='table' then
    for k,v in pairs(o) do
      print(k,v)
    end
  end
end

function timer_update()
  -- params=softcut.params()
  -- print(dump(params[1].position.controlspec.warp))
  -- only use timer when state is activated
  if flag_update_screen then
    redraw()
  elseif state_activated then
    state_current_time=state_current_time+const_time_per_refresh
    print(state_current_time)
    if param_repeats>0 and state_current_time>=param_loop_length*param_repeats then
      deactivate_basic()
    end
  end
end

function activate_basic()
  if state_activated then
    deactivate_basic()
    do return end
  end
  current_position=state_current_position
  prev_position=current_position-param_loop_length
  if prev_position<1 then
    prev_position=1
  end
  slew_rate=param_repeats*param_loop_length
  if slew_rate<0 then
    slew_rate=param_loop_length
  end
  print(current_position,prev_position)
  audio.level_monitor(param_monitor)
  softcut.rec(1,0) -- stop recording
  softcut.level(1,1) -- start playing
  softcut.position(1,prev_position)
  softcut.loop_start(1,prev_position)
  softcut.loop_end(1,current_position)
  softcut.rate_slew_time(1,2*slew_rate)
  softcut.level_slew_time(1,slew_rate)
  softcut.pan_slew_time(1,slew_rate)
  softcut.rate(1,param_final_rate)
  softcut.level(1,param_final_level)
  state_current_time=0
  state_repeat_number=0
  state_activated=true
end

function deactivate_basic()
  print("deactivated")
  state_activated=false
  audio.level_monitor(1)
  softcut.rec(1,1) -- start recording
  softcut.position(1,state_current_position+1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,300)
  softcut.rate_slew_time(1,0)
  softcut.level_slew_time(1,0)
  softcut.pan_slew_time(1,0)
  softcut.rate(1,1)
  softcut.level(1,1)
end

function enc(n,d)
  if n==2 then
    param_final_level=util.clamp(param_final_level+d/100,0,1)
    if state_activated then
      softcut.level(1,param_final_level)
    end
  elseif n==3 then
    param_final_rate=util.clamp(param_final_rate+d/100,-4,4)
    if state_activated then
      softcut.rate(1,param_final_rate)
    end
  end
end

function key(n,z)
  if n==2 and z==1 then
    -- initiate
    activate_basic()
  end
end

function redraw()
  screen.clear()
  
end
