-- clcks v0.1
-- tempo-locked repeat
--
-- llllllll.co/t/clcks
--
--
--
--    ▼ instructions below ▼
--
-- press K2 or K3 to activate
-- press K2 or K3 to deactivate
-- (K2 keeps monitoring audio)
-- E1 changes repeat number
-- E2/E3 change final level/rate
--
-- hold K1 to shift
-- shift+E2 changes bpm
-- shift+E3 changes beat subdivision
-- shift+K2 resets parameters
-- shift+K3 randomizes
--
--

state={
  activated=false,
  time=0,
  repeats=0,
  beat=0,
  position=0,
  shift=false,
  tick=false,
  update_screen=false,
}

params={
  tempo=90,
  level=1,
  rate=1,
  repeats=3,
  subdivided=1,
  randomizer="off",
}

function init()
  audio.level_adc_cut(1) -- send audio input to softcut input
  audio.level_monitor(1)
  
  -- initialize softcut
  softcut.buffer_clear()
  for i=1,2 do
    softcut.enable(i,1)
    softcut.level(i,1)
    softcut.buffer(i,i) -- l&r use buffers 1&2
    softcut.loop(i,1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,300)
    softcut.position(i,1)
    softcut.play(i,1)
    softcut.rate_slew_time(i,0)
    softcut.level_slew_time(i,0)
    softcut.pan(i,(i-1)*2-1) --stereo
    softcut.rec_level(i,1.0)
    softcut.pre_level(i,0.0)
    softcut.level_input_cut(i,i,1.0)
    softcut.rec(i,1) -- always be recording
  end
  
  -- initialize timer
  timer=metro.init()
  timer.time=60/params.tempo/16
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  -- position poll
  -- monitor one position to get both, since they are synced
  softcut.phase_quant(1,0.025)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end

function update_clock(x)
  timer.time=60/x/16
end

function update_level(x)
  if state.activated then
    for i=1,2 do
      softcut.level(i,params.level)
    end
  end
end

function update_rate(x)
  if state.activated then
    for i=1,2 do
      softcut.rate(i,params.rate)
    end
  end
end

function update_positions(i,x)
  state.position=x
end

function update_timer()
  if state.activated then
    state.time=state.time+const_time_per_refresh
    state.tick=round(state.time/(60/params.tempo))%2==1
    
    -- get repeat number
    current_repeat=state.repeats
    state.repeats=math.floor(state.time/loop_length())
    if state.repeats>current_repeat then
      state.update_screen=true
    end
    
    -- get beat number
    current_beat_number=state.beat
    state.beat=1+math.floor(state.time/(loop_length()))%params.subdivided
    if state.beat~=current_beat_number then
      state.update_screen=true
    end
    
    if params.repeats<10 and state.time>=loop_length()*params.repeats then
      deactivate_basic()
    end
  end
  if state.update_screen then
    redraw()
  end
end

function loop_length()
  return 60/params.tempo/params.subdivided
end

function activate_basic(monitor_mode)
  if state.activated then
    deactivate_basic()
    do return end
  end
  current_position=state.position
  prev_position=current_position-loop_length()
  if prev_position<1 then
    prev_position=1
  end
  slew_rate=params.repeats*loop_length()*4
  if slew_rate<0 then
    slew_rate=loop_length()
  end
  audio.level_monitor(monitor_mode)
  for i=1,2 do
    softcut.rec(i,0) -- stop recording
    softcut.level(i,1) -- start playing
    softcut.position(i,prev_position)
    softcut.loop_start(i,prev_position)
    softcut.loop_end(i,current_position)
    softcut.rate_slew_time(1,2*slew_rate)
    softcut.level_slew_time(i,slew_rate)
    softcut.rate(i,params.rate)
    softcut.level(i,params.level)
  end
  state.time=0
  state.repeats=0
  state.activated=true
  state.update_screen=true
end

function deactivate_basic()
  print("deactivated")
  state.activated=false
  audio.level_monitor(1)
  for i=1,2 do
    softcut.rec(i,1) -- start recording
    softcut.position(i,state.position+1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,300)
    softcut.rate_slew_time(i,0)
    softcut.level_slew_time(i,0)
    softcut.rate(i,1)
    softcut.level(i,1)
  end
  state.update_screen=true
end

function randomizer()
  clock.sleep(math.random(0,10))
  if params.randomizer=="off" then
    do return end
  end
  params.level=math.random(0,1)
  params.rate=math.random(-4,4)
  params.repeats=round(math.random(1,5))
  params.subdivided=round(math.random(1,8))
  monitor_mode=round(math.random())
  state.update_screen=true
  activate_basic(monitor_mode)
  clock.run(randomizer)
end

function enc(n,d)
  if n==1 then
    if state.shift then
    else
      params.repeats=util.clamp(params.repeats+d,1,10)
    end
  elseif n==2 then
    if state.shift then
      params.tempo=util.clamp(params.tempo+d,10,500)
    else
      params.level=util.clamp(params.level+d/100,0,1)
      update_level(0)
    end
  elseif n==3 then
    if state.shift then
      params.subdivided=util.clamp(params.subdivided+d,1,16)
    else
      -- turning ccw sets to reverse
      -- turning cw sets to forward
      params.rate=sign(d)*math.abs(util.clamp(params.rate+d/100,-4,4))
      update_rate(0)
    end
  end
  state.update_screen=true
end

function key(n,z)
  if n==2 and z==1 then
    if state.shift then
      -- reset final parameters
      params.randomizer="off"
      params.rate=1
      params.level=1
    else
      -- initiate with monitor mode
      activate_basic(1)
    end
  elseif n==3 and z==1 then
    if state.shift then
      -- randomize chop
      params.randomizer="on"
      clock.run(randomizer)
    else
      -- initate without monitor mode
      activate_basic(0)
    end
  elseif n==1 then
    state.shift=z==1
  end
  state.update_screen=true
end

function redraw()
  state.update_screen=false
  
  screen.clear()
  
  -- check shift
  shift_amount=0
  if state.shift then
    shift_amount=4
  end
  
  -- draw bpm
  screen.move(3+shift_amount,8+shift_amount)
  screen.text(params.tempo)
  metro_icon(16+shift_amount,3+shift_amount)
  
  -- draw beat subidivision boxes
  x=34+shift_amount
  y=4+shift_amount
  w=3
  show_beats=params.subdivided
  if state.activated then
    show_beats=current_beat_number
  end
  for i=1,show_beats do
    screen.move(x,y)
    screen.rect(x,y,w,w)
    screen.stroke()
    x=x+w+2
  end
  
  -- draw clocks
  x=2 -- x, y are the top left hand point
  y=20
  h=40
  w=round(120/params.repeats)
  show_repeats=params.repeats
  if state.activated then
    show_repeats=state.repeats
  end
  short_hand_angle=180*math.abs(params.rate)/4+90
  rinitial=w/2
  rfinal=w/2*params.level
  print(params.level)
  for i=1,show_repeats do
    -- default: interpolate level between beginning and end
    r=rinitial*(params.repeats-i)/(params.repeats-1)
    r=r+rfinal*(1-(params.repeats-i)/(params.repeats-1))
    if i==1 then
      r=rinitial
    elseif i==state.repeats then
      r=rfinal
    end
    r=r+2
    
    -- draw ellipse with short radius showing interpolated level
    center={x+w/2,y+w/2}
    screen.move(center[1],y)
    screen.curve(center[1]-r,y,center[1]-r,y+h,center[1],y+h)
    screen.stroke()
    screen.move(center[1],y)
    screen.curve(center[1]+r,y,center[1]+r,y+h,center[1],y+h)
    screen.stroke()
    
    -- short hand indicates absolute rate
    screen.move(center[1],center[2])
    screen.line(center[1]+r/3*math.sin(math.rad(short_hand_angle)),center[2]+r/3*math.cos(math.rad(short_hand_angle)))
    screen.stroke()
    
    -- long hand indicates direction of rate
    angle=(i-1)*36
    if params.rate>0 then
      angle=360-angle
    end
    angle=angle-180
    angle=-1*angle
    
    screen.move(center[1],center[2])
    screen.line(center[1]+r*math.sin(math.rad(angle)),center[2]+r*math.cos(math.rad(angle)))
    screen.stroke()
    
    -- update x position
    x=x+w -- TODO: try using r instead
  end
  
  screen.update()
end

--- Creates icon to show beat relative to interval.
-- Thenk you @itsyourbedtime for creating this for Takt!
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- @tparam tick {boolean}
function metro_icon(x,y)
  screen.move(x+2,y+5)
  screen.line(x+7,y)
  screen.line(x+12,y+5)
  screen.line(x+3,y+5)
  screen.stroke()
  screen.move(x+7,y+3)
  screen.line(state.tick and (x+4) or (x+10),y)
  screen.stroke()
end

function round(num)
  under=math.floor(num)
  upper=math.floor(num)+1
  underV=-(under-num)
  upperV=upper-num
  if (upperV>underV) then
    return under
  else
    return upper
  end
end

function sign(num)
  if num<0 then
    return-1
  else
    return 1
  end
end
