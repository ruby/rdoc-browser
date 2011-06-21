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
    attr_accessor :message

    def initialize content
      @current_row = 0

      super Curses.lines - 1, Curses.cols

      @formatter = RDoc::Markup::ToCurses.new self
      @message = nil

      show content

      refresh
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

    def show content
      @formatter.convert content

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

To look up a class, module method, or other documented item press 'g' followed
by the item you would like to look up.

To quit, press q, ^C or ^D

Use the arrow keys, page up, page down, home or end to scroll.

Tab and shift-tab will navigate through links.

Control-left and control-right will you back and forth in the history.
  HELP

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
  end

  def display document
    @display.close

    @display = RDoc::Curses::Display.new document
  end

  def display_name name
    return if display_class name

    display_method name if name =~ /::|#|\./

    true
  rescue NotFoundError
    @message.error "#{name} not found"
  end

  def run
    Curses.init_screen

    if Curses.start_color then
      Curses.use_default_colors
      @colors = true
      # This is a a hack.  I'm abusing the COLOR_GREEN constant to make a
      # green on default background color pair.
      Curses.init_pair Curses::COLOR_GREEN, Curses::COLOR_GREEN, -1
    end

    Curses.raw
    Curses.noecho
    Curses.curs_set 0 # invisible

    @message = RDoc::Curses::Message.new

    @display = RDoc::Curses::Display.new HELP
    @display.message = @message

    trap 'CONT' do
      Curses.doupdate
    end

    event_loop
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

end

