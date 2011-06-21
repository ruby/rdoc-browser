require 'curses'
require 'rdoc'
require 'rdoc/ri/driver'
require 'rdoc/markup/to_curses'

class RDoc::Curses < RDoc::RI::Driver

  ##
  # The version of rdoc-curses you are using

  VERSION = '1.0'

  class Display < Curses::Pad

    attr_reader :current_row

    def initialize driver
      super Curses.lines - 1, Curses.cols

      @driver = driver
      @message = driver.message

      clear
    end

    def clear
      @current_row = 0
      setpos 0, 0

      resize 0, Curses.cols

      noutrefresh
    end

    alias rows maxy

    def page_down
      @current_row += Curses.lines - 1

      noutrefresh
    end

    def page_up
      @current_row -= Curses.lines - 1

      noutrefresh
    end

    def screen_position
      @current_row = 0       if @current_row < 0
      @current_row = max_row if @current_row > max_row

      [@current_row, 0, 0, 0, Curses.lines - 2, Curses.cols]
    end

    def scroll_bottom
      @current_row = max_row

      noutrefresh
    end

    def scroll_down
      @current_row += 1

      noutrefresh
    end

    def scroll_top
      @current_row = 0

      noutrefresh
    end

    def scroll_up
      @current_row -= 1

      noutrefresh
    end

    def show content, context
      clear

      formatter = RDoc::Markup::ToCurses.new self, context, @driver

      formatter.convert content

      noutrefresh
    end

    def max_row
      maxy - Curses.lines + 1
    end

    def noutrefresh
      super(*screen_position)
    end

    def refresh
      super(*screen_position)
    end

  end

  class Message < Curses::Window

    def initialize
      super 1, Curses.cols, Curses.lines - 1, 0

      keypad true
    end

    def clear
      setpos 0, 0
      clrtoeol
      noutrefresh
    end

    def error message
      clear
      addstr message
      noutrefresh
      Curses.flash
    end

    def prompt
      clear

      attron Curses::A_BOLD do
        addstr '> '
      end

      Curses.echo

      return getstr
    ensure
      Curses.noecho
      clear
    end

    def show message
      clear
      addstr message
      noutrefresh
    end

  end

  ##
  # Welcome message

  HELP = <<-HELP.gsub(/([\w.])\n(\w)/m, '\1 \2')
This is ri + curses

To look up a class, module, method, or other documented item press 'g' then
enter the name of the item you would like to look up.

To quit, press Q, ^C or ^D

To suspend press Z or ^Z

Use the arrow keys, page up, page down, home or end to scroll.

Tab will navigate through links.

Shift-left and shift-right will you back and forward in the history.
  HELP

  attr_accessor :message

  def initialize
    options = {
      use_system:     true,
      use_site:       true,
      use_home:       true,
      use_gems:       true,
      use_cache:      true,
      extra_doc_dirs: [],
    }

    super options

    @colors = false
    @message = nil
    @display = nil
  end

  def display document, context
    @display.show document, context
  end

  def display_class name
    return if name =~ /#|\./

    found, klasses, includes = classes_and_includes_for name

    context = klasses.reverse.inject do |merged, k|
      merged.merge k
    end

    return if found.empty?

    out = class_document name, found, klasses, includes

    display out, context
  end

  def display_name name
    return if display_class name

    display_method name if name =~ /::|#|\./

    true
  rescue NotFoundError
    @message.error "#{name} not found"
  end

  def find_module_named name
    found = @stores.map do |store|
      store.cache[:modules].find_all { |m| m == name }
    end.flatten.uniq

    @message.show found.inspect

    not found.empty?
  end

  def event_loop
    loop do
      Curses.doupdate
      @message.clear

      case key = @message.getch
      when      Curses::Key::END   then @display.scroll_bottom
      when      Curses::Key::HOME  then @display.scroll_top
      when 'j', Curses::Key::DOWN  then @display.scroll_down
      when 'k', Curses::Key::UP    then @display.scroll_up
      when ' ', Curses::Key::NPAGE then @display.page_down
      when      Curses::Key::PPAGE then @display.page_up

      #when 'i' then @message.show "color: #{@colors}"

      when 'Q', 3, 4 then break # ^C, ^D
      when 'Z', 26, Curses::Key::SUSPEND then
        Curses.close_screen
        Process.kill 'STOP', $$

      when 'g' then display_name @message.prompt

      else
        @message.error "unknown key #{key.inspect}"
      end
    end
  end

  def run
    Curses.init_screen

    if Curses.start_color then
      Curses.use_default_colors
      @colors = true
      # This is a a hack.  I'm abusing the COLOR_ constants to make a color on
      # default background color pair.
      Curses.init_pair Curses::COLOR_GREEN, Curses::COLOR_GREEN, -1
      Curses.init_pair Curses::COLOR_CYAN,  Curses::COLOR_CYAN,  -1
    end

    Curses.raw
    Curses.noecho
    Curses.curs_set 0 # invisible

    @message = RDoc::Curses::Message.new

    @display = RDoc::Curses::Display.new self
    @display.show HELP, nil

    old_cont = trap 'CONT' do
      Curses.doupdate
    end

    event_loop
  ensure
    trap 'CONT', old_cont if old_cont
  end

end

