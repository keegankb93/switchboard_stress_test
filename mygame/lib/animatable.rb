module Animatable
  attr_accessor :current_animation, :animation_started_at

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def define_animations(tile_w: nil, tile_h: nil, &block)
      sheets = Sheets.build(tile_w, tile_h)

      sheets.instance_eval(&block)

      @animations = sheets.animations
    end

    def animations
      @animations
    end
  end

  def animations
    self.class.animations
  end

  # One animation. It can be a sprite sheet or numbered files.
  Animation = Struct.new(:name, :path, :tile_w, :tile_h, :columns, :start, :frames, :start_frame, :hold_for, :repeat,
                         :sequence) do
    def self.create(name:,
                    path:,
                    tile_w:,
                    tile_h:,
                    columns:,
                    start:,
                    frames:,
                    start_frame: 0,
                    hold_for: 3,
                    repeat: true,
                    sequence: false)
      row, col = start
      start_index = row * columns + col

      new(name, path, tile_w, tile_h, columns, start_index, frames, start_frame, hold_for, repeat, sequence)
    end

    def frame_count
      frames
    end

    def frame_cell(i)
      index = start + i

      [index / columns, index % columns]
    end

    def frame_path(i)
      return path unless sequence

      path.sub(':index', (start + i).to_s)
    end
  end

  # Holds every animation defined by `define_animations`.
  Sheets = Struct.new(:tile_w, :tile_h, :animations) do
    def self.build(tile_w, tile_h)
      new(tile_w, tile_h, {})
    end

    def sheet(path, columns:, tile_w: nil, tile_h: nil, &block)
      Sheet.new(path, tile_w || self.tile_w, tile_h || self.tile_h, columns, animations).instance_eval(&block)
    end

    def folder(dir, ext: :png, tile_w: nil, tile_h: nil, &block)
      Folder.new(dir, ext, tile_w || self.tile_w, tile_h || self.tile_h, animations).instance_eval(&block)
    end

    def sequence(name, path:, frames:, start_frame: 0, hold_for: 3, repeat: true, start: 0, tile_w: nil, tile_h: nil)
      animations[name] = Animation.create(
        name: name,
        path: path,
        tile_w: tile_w || self.tile_w,
        tile_h: tile_h || self.tile_h,
        columns: frames,
        start: [0, start],
        frames: frames,
        start_frame: start_frame,
        hold_for: hold_for,
        repeat: repeat,
        sequence: true
      )
    end
  end

  Sheet = Struct.new(:path, :tile_w, :tile_h, :columns, :animations) do
    def anim(name, start:, frames:, start_frame: 0, hold_for: 3, repeat: true)
      animations[name] = Animation.create(
        name: name,
        path: path,
        tile_w: tile_w,
        tile_h: tile_h,
        columns: columns,
        start: start,
        frames: frames,
        start_frame: start_frame,
        hold_for: hold_for,
        repeat: repeat
      )
    end
  end

  Folder = Struct.new(:dir, :ext, :tile_w, :tile_h, :animations) do
    def anim(name, frames:, columns: nil, start: [0, 0], start_frame: 0, hold_for: 3, repeat: true)
      animations[name] = Animation.create(
        name: name,
        path: "#{dir}/#{name}.#{ext}",
        tile_w: tile_w,
        tile_h: tile_h,
        columns: columns || frames,
        start: start,
        frames: frames,
        start_frame: start_frame,
        hold_for: hold_for,
        repeat: repeat
      )
    end
  end

  def modifiers
    @modifiers ||= {}
  end

  def modify_animations(*names, **changes)
    names.each { |name| (modifiers[name] ||= {}).merge!(changes) }
  end

  def play_animation(name)
    return if current_animation == name

    self.current_animation = name

    animation = animations.fetch(name)
    self.animation_started_at = Kernel.tick_count - (animation.start_frame * animation.hold_for)
  end

  def animation_sprite
    animation = animations.fetch(current_animation)

    index = animation_frame_index(animation) || (animation.frame_count - 1)
    sprite = {
      x: x.to_i,
      y: y.to_i,
      w: w,
      h: h,
      path: animation.path,
      flip_horizontally: flip_animation?
    }

    return sprite.merge!(path: animation.frame_path(index)) if animation.sequence

    row, col = animation.frame_cell(index)

    sprite.merge!(tile_x: col * animation.tile_w,
                  tile_y: row * animation.tile_h,
                  tile_w: animation.tile_w,
                  tile_h: animation.tile_h)
  end

  def animation_finished?
    return false unless animation_started_at

    animation = animations.fetch(current_animation)

    return false if animation.repeat

    animation_frame_index(animation).nil?
  end

  def flip_animation?
    false
  end

  private

  def modifier(name, key, default)
    mod = modifiers[name]

    (mod && mod[key]) || default
  end

  def animation_frame_index(animation)
    return 0 unless animation_started_at

    speed = modifier(animation.name, :speed, 1)
    hold = (animation.hold_for / speed).to_i
    hold = 1 if hold < 1
    animation_started_at.frame_index(animation.frame_count, hold, animation.repeat)
  end
end
