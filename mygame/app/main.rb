require 'lib/switchboard'
require 'lib/animatable'

class Player
  include Switchboard
  include Animatable

  attr_accessor :x, :y, :w, :h, :dx, :dy, :facing, :jump_at, :jump_count,
                :max_speed, :requested_action, :requested_action_at,
                :next_action_queue, :action_at

  HOLD_FOR = 5

  ACTIONS = {
    slash_0: {
      frames: 6,
      length: 30,
      interrupt_after: 20,
      next: :slash_1,
      path: 'sprites/kenobi/slash-0/:index.png'
    },
    slash_1: {
      frames: 6,
      length: 30,
      interrupt_after: 20,
      next: :throw_0,
      path: 'sprites/kenobi/slash-1/:index.png'
    },
    throw_0: {
      frames: 8,
      length: 40,
      interrupt_after: 40,
      next: :throw_1,
      throw_at: 10,
      catch_at: 30,
      path: 'sprites/kenobi/slash-2/:index.png'
    },
    throw_1: {
      frames: 9,
      length: 45,
      interrupt_after: 45,
      next: :throw_2,
      throw_at: 10,
      catch_at: 35,
      path: 'sprites/kenobi/slash-3/:index.png'
    },
    throw_2: {
      frames: 9,
      length: 45,
      interrupt_after: 45,
      next: :slash_5,
      throw_at: 10,
      catch_at: 35,
      path: 'sprites/kenobi/slash-4/:index.png'
    },
    slash_5: {
      frames: 11,
      length: 55,
      interrupt_after: 55,
      next: :slash_6,
      path: 'sprites/kenobi/slash-5/:index.png'
    },
    slash_6: {
      frames: 8,
      length: 40,
      interrupt_after: 30,
      next: nil,
      path: 'sprites/kenobi/slash-6/:index.png'
    }
  }

  # The original actions become our attack states
  ATTACKS = ACTIONS.keys

  # All states, which is just the non-attack state + attacks
  STATES = [:standing] + ATTACKS

  define_animations tile_w: 16, tile_h: 16 do
    # Sequence is a series of frames that are played in order (separate files)
    sequence :standing, path: 'sprites/kenobi/standing.png', frames: 1, hold_for: HOLD_FOR
    sequence :jumping, path: 'sprites/kenobi/jumping.png', frames: 1, hold_for: HOLD_FOR
    sequence :run, path: 'sprites/kenobi/run/:index.png', frames: 4, hold_for: HOLD_FOR
    sequence :second_jump, path: 'sprites/kenobi/second-jump/:index.png', frames: 8, hold_for: HOLD_FOR, repeat: false

    # Since they all have the same data shape we can use ACTIONS to define them all
    ACTIONS.each do |name, data|
      sequence name, path: data[:path], frames: data[:frames], hold_for: HOLD_FOR, repeat: false
    end
  end

  switchboard do
    # Make sure that every state plays the correct animation when entered
    STATES.each do |name|
      state name, initial: name == :standing do
        after_enter :start_animation_for_current_state
      end
    end

    # An attack can be transitioned to from any state but itself
    ATTACKS.each do |name|
      event name do
        transition from: STATES - [name], to: name
      end
    end

    # The stand event can be triggered from any attack state to return to standing
    event :stand do
      transition from: ATTACKS, to: :standing
    end
  end

  def initialize
    @x = 64
    @y = 0
    @w = 16
    @h = 16
    @dx = 0
    @dy = 0
    @facing = 1
    @jump_at = 0
    @jump_count = 0
    @max_speed = 1.0
    @action_at = 0
    @next_action_queue = {}

    play_animation :standing
  end

  #
  # Old code used action and we're using current_state as the action with switchboard
  def action
    current_state
  end

  #
  # Trigger an action event
  def start_action(name)
    # return if we're already in this state
    return false if action == name

    # either we standin' or we attackin'
    name == :standing ? stand : send(name)
  end

  #
  # Play the animation for the current state this is called directly after
  # the state has transitioned
  def start_animation_for_current_state
    self.action_at = Kernel.tick_count
    play_animation action
  end

  # Restart the animation for the given state
  def restart_animation(name)
    self.current_animation = nil
    play_animation name
  end

  #
  # Standing animation/state is kind of a catch-all for any non-combative action
  # So essentially depending on how we're "standing"/moving we want to play a different animation
  # i.e. jumping
  def update_standing_animation
    return unless standing?

    if y != 0
      play_animation(jump_count <= 1 ? :jumping : :second_jump)
    elsif dx != 0
      play_animation :run
    else
      play_animation :standing
    end
  end

  #
  # This is just from the old code where the sprite has an offset so we're just
  # taking the animation_sprite from animatable.rb and adding that offset
  def animation_sprite
    sprite = super
    sprite[:x] = x + 1 - 8
    sprite
  end

  #
  # Flip left or right based on facing direction
  def flip_animation?
    facing == -1
  end
end

class Game
  attr_dr

  def tick
    defaults
    calc
    render
  end

  def defaults
    state.player ||= Player.new
    state.sabre.x ||= player.x
    state.sabre.y ||= player.y
  end

  # Convenience method to get the player in state
  def player
    state.player
  end

  # Get the action data for the given action name
  def action_data(name)
    Player::ACTIONS[name]
  end

  def render
    outputs.background_color = [32, 32, 32]

    outputs[:scene].w = 128
    outputs[:scene].h = 128
    outputs[:scene].borders << { x: 0, y: 0, w: 128, h: 128, r: 255, g: 255, b: 255 }

    render_player
    render_sabre

    outputs.sprites << { x: 320, y: 0, w: 640, h: 640, path: :scene }
    outputs.labels << { x: 10, y: 120, text: "State:  #{player.action}", r: 210, g: 230, b: 255, size_enum: -1 }
    outputs.labels << { x: 10, y: 100, text: "Anim:   #{player.current_animation}", r: 210, g: 230, b: 255,
                        size_enum: -1 }
    outputs.labels << { x: 10, y: 80, text: 'Move:   left/right', r: 255, g: 255, b: 255, size_enum: -1 }
    outputs.labels << { x: 10, y: 60, text: 'Jump:   space | up | right click', r: 255, g: 255, b: 255, size_enum: -1 }
    outputs.labels << { x: 10, y: 40, text: 'Attack: f     | j  | left click', r: 255, g: 255, b: 255, size_enum: -1 }
  end

  def render_player
    # Running, jumping, or standing
    player.update_standing_animation
    outputs[:scene].sprites << player.animation_sprite
  end

  def render_sabre
    return unless state.sabre.is_active

    frame = 0.frame_index count: 4, hold_for: 2, repeat: true
    offset = player.facing == -1 ? -8 : 0

    outputs[:scene].sprites << {
      x: state.sabre.x + offset,
      y: state.sabre.y,
      w: 16,
      h: 16,
      path: "sprites/sabre-throw/#{frame}.png"
    }
  end

  def calc
    read_input
    queue_requested_attack
    start_queued_action
    move_sabre
    move_player
  end

  def read_input
    request_attack if attack_button_pressed?
    move_left_and_right
    jump_if_possible
  end

  def attack_button_pressed?
    inputs.controller_one.key_down.a ||
      inputs.mouse.button_left ||
      inputs.keyboard.key_down.j ||
      inputs.keyboard.key_down.f
  end

  #
  # Request an attack and then later we'll check the time it was requested
  # to determine when to actually perform the attack
  def request_attack
    player.requested_action = :attack
    player.requested_action_at = Kernel.tick_count
  end

  # uh move left and right xD
  def move_left_and_right
    direction = inputs.left_right

    if should_update_facing? && direction.sign != player.facing.sign
      player.dx = 0

      if inputs.left
        player.facing = -1
      elsif inputs.right
        player.facing = 1
      end

      player.dx += 0.1 * direction
    end

    return unless player.standing?

    player.dx += 0.1 * direction
    player.dx = player.max_speed * player.dx.sign if player.dx.abs > player.max_speed
  end

  def should_update_facing?
    return true if player.standing?

    key_0 = player.next_action_queue.keys[0]
    key_1 = player.next_action_queue.keys[1]

    Kernel.tick_count == key_0 ||
      Kernel.tick_count == key_1 ||
      (key_0 && key_1 && Kernel.tick_count.between?(key_0, key_1))
  end

  #
  # This is also what we use for flip_animation? (the -1, 1)
  def left_right_input
    return -1 if inputs.left
    return 1 if inputs.right

    inputs.left_right.sign
  end

  def jump_if_possible
    return unless jump_button_pressed?
    return unless player.jump_at.elapsed_time > jump_cooldown

    # if we're performing the last slash, clear the queue and go to standing
    # (you can still continue to jump in the air, but you will slash down)
    if player.slash_6?
      player.next_action_queue.clear
      player.start_action :standing
    end

    player.dy = 1
    player.jump_count += 1
    player.jump_at = Kernel.tick_count

    # Continue to play the second_jump animation if we're still second_jumping (we don't want to put the animation in a loop)
    player.restart_animation :second_jump if player.jump_count > 1
  end

  def jump_button_pressed?
    inputs.keyboard.key_down.up ||
      inputs.keyboard.key_down.w ||
      inputs.mouse.button_right ||
      inputs.controller_one.key_down.up ||
      inputs.controller_one.key_down.b ||
      inputs.keyboard.key_down.space
  end

  def jump_cooldown
    player.jump_count <= 1 ? 10 : 20
  end

  def queue_requested_attack
    # if we're not attackin' we're standin'
    return unless player.requested_action == :attack

    # ignore the request if it's in the future (we'll get to it)
    return if player.requested_action_at > Kernel.tick_count

    # clear the queue and queue the attack
    # This whole queue system is more like a "buffer" where we're queuing and we WILL
    # play through the attacks, but if you are spamming attacks it's going to clear whatever it has
    # to play and then it will play the attack you requested and continue through the combo
    player.next_action_queue.clear

    if player.standing?
      # Always start with slash_0 when standing
      queue_action Kernel.tick_count, :slash_0

      # If an attack doesn't get queued up after, we need to return to standing after X ticks from the action_data
      queue_action Kernel.tick_count + action_data(:slash_0)[:length], :standing
    else
      queue_next_combo_action
    end

    # Clear the requested action after queuing
    player.requested_action = nil
    player.requested_action_at = nil
  end

  def queue_next_combo_action
    # Get the action data
    current_action = action_data(player.action)

    # Prep up the next attack in the combo or if there isnt any go back to standing
    next_action = current_action[:next] || :standing

    # Start the next action after the interrupt_after time has passed
    # Basically interrupt just says "you can start your action even though i'm not done with mine"
    interrupt_at = player.action_at + current_action[:interrupt_after]
    start_at = interrupt_at

    # If the action start at has already passed, just play it now
    start_at = Kernel.tick_count if start_at < Kernel.tick_count

    length = next_action == :standing ? 4 : action_data(next_action)[:length]

    # Queue the next attack
    queue_action start_at, next_action

    # If no attack is made after the above make sure we return to standing
    queue_action interrupt_at + length, :standing
  end

  def queue_action(tick, action)
    # Register action to be played at the specified tick
    # { 100 => :standing, 200 => :slash_0 }
    player.next_action_queue[tick] = action
  end

  def start_queued_action
    # Get the action for the current tick
    action = player.next_action_queue[Kernel.tick_count]

    return unless action

    # return if already playing
    return unless player.start_action(action)

    apply_action_air_movement
  end

  # Floaty maths
  def apply_action_air_movement
    in_air = player.y != 0

    if player.slash_0? || player.slash_1?
      player.dy = 0 if player.dy > 0
      if in_air
        player.dy = 0.5
      else
        player.dx += 0.25 * player.facing
      end
    elsif player.throw_0? || player.throw_1? || player.throw_2?
      player.dy = 1.0 if in_air
      player.dx += 0.5 * player.facing
    elsif player.slash_5?
      player.dy = 0 if player.dy < 0
      player.dy += 1.0
      player.dx += 1.0 * player.facing
    elsif player.slash_6?
      player.dy = 0 if player.dy > 0
      player.dy = -0.5 if in_air
      player.dx += 0.5 * player.facing
    end
  end

  def move_sabre
    # Hide the sabre if not throwing
    unless %i[throw_0 throw_1 throw_2].include? player.action
      hide_sabre
      return
    end

    current_action = action_data(player.action)
    throw_at = player.action_at + current_action[:throw_at]
    catch_at = player.action_at + current_action[:catch_at]

    # Show the sabre during the throw/catch period
    unless Kernel.tick_count.between? throw_at, catch_at
      hide_sabre
      return
    end

    state.sabre.facing ||= player.facing
    state.sabre.is_active = true

    progress = Easing.spline throw_at,
                             Kernel.tick_count,
                             catch_at - throw_at,
                             [[0, 0.25, 0.75, 1.0], [1.0, 0.75, 0.25, 0]]

    state.sabre.y = player.y
    state.sabre.x = player.x + 32 * progress * state.sabre.facing
  end

  def hide_sabre
    state.sabre.facing = nil
    state.sabre.is_active = false
  end

  def move_player
    player.x += player.dx
    player.y += player.dy
    player.dy -= 0.05

    land_player if player.y <= 0

    player.dx = 0 if player.dx.abs < 0.09
    player.x = 8 if player.x < 8
    player.x = 120 if player.x > 120
  end

  def land_player
    player.y = 0
    player.dy = 0
    player.jump_at = 0
    player.jump_count = 0
  end
end

$game = Game.new

def tick(args)
  $game.args = args
  $game.tick
end

DR.reset

DR.recording.on_replay_completed_successfully do |args|
  raise 'Player was not in the right place' if args.state.player.x.floor != 64

  puts 'Player in correct position'
end
