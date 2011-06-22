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

    attr_reader :links

    def initialize driver
      super Curses.lines - 1, Curses.cols

      @driver = driver
      @message = driver.message

      clear
    end

    def clear
      @current_row = 0
      @links = []
      @current_link = -1
      setpos 0, 0

      resize 0, Curses.cols

      super

      noutrefresh
    end

    def current_link
      return nil if @current_link == -1

      @links[@current_link].last
    end

    def next_link
      return if @links.empty?

      write_link @current_link, @driver.link_style

      @current_link += 1
      @current_link = 0 if @current_link >= @links.length

      write_link @current_link, @driver.hover_style

      scroll_to @links[@current_link].first
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

    def previous_link
      return if @links.empty?

      write_link @current_link, @driver.link_style

      @current_link -= 1
      @current_link = @links.length - 1 if @current_link < 0

      write_link @current_link, @driver.hover_style

      scroll_to @links[@current_link].first
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

    def scroll_to row
      height = Curses.lines - 2

      if row < @current_row then
        @current_row = row
      elsif row > @current_row + height then
        @current_row = row
      end

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

    def show content, context, crossref = true
      clear

      formatter = RDoc::Markup::ToCurses.new self, crossref, context, @driver

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

    def write_link index, style
      return if index == -1

      y, x, text = @links[index]

      setpos y, x

      attrset style
      addstr text
      attrset Curses::A_NORMAL

      setpos y, x # move cursor

      noutrefresh
    end

  end

  class History

    attr_reader :position

    def initialize
      @pages = []
      @position = 0
    end

    def back
      return if @position == 0

      @position -= 1

      _, content, context = @pages[@position]

      [content, context]
    end

    def forward
      return if @position >= @pages.length - 1

      @position += 1

      _, content, context = @pages[@position]

      [content, context]
    end

    def go name, content, context
      @pages.slice! @position + 1, @pages.length unless
        @position == @pages.length

      @pages << [name, content, context]

      @position = @pages.length - 1
    end

    def pages
      @pages.map { |name,| name }
    end

    def list
      out = RDoc::Markup::Document.new
      out << RDoc::Markup::Heading.new(1, 'History')
      out << RDoc::Markup::BlankLine.new

      unless @pages.empty? then
        list = RDoc::Markup::List.new :NUMBER

        @pages.each_with_index do |(name,_,_), i|
        name = "*#{name}*" if i == @position

        name = RDoc::Markup::Paragraph.new name

        list << RDoc::Markup::ListItem.new(nil, name)
        end

        out << list
      else
        out << RDoc::Markup::Paragraph.new('Your history is empty')
      end

      out
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
  attr_reader :link_style
  attr_reader :hover_style
  attr_reader :history

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

    @colors  = false
    @message = nil
    @display = nil
    @history = History.new
  end

  def display document, context, crossref = true
    @display.show document, context, crossref

    true
  end

  def display_class name
    return if name =~ /#|\./

    found, klasses, includes = classes_and_includes_for name

    context = klasses.reverse.inject do |merged, k|
      merged.merge k
    end

    return if found.empty?

    out = class_document name, found, klasses, includes

    @history.go name, out, context

    display out, context
  end

  def display_method name
    found = load_methods_matching name

    raise NotFoundError, name if found.empty?

    filtered = filter_methods found, name

    out = method_document name, filtered

    @history.go name, out, nil

    display out
  end

  def display_name name
    return if display_class name

    display_method name if name =~ /::|#|\./

    true
  rescue NotFoundError
    @message.error "#{name} not found"
  end

  def event_loop
    loop do
      Curses.doupdate
      @message.clear

      case key = @message.getch
      when 9                       then @display.next_link
      when 'Z'                     then @display.previous_link # shift-tab

      when 10,  Curses::Key::ENTER then display_name @display.current_link

      when      Curses::Key::LEFT  then go_to @history.back
      when      Curses::Key::RIGHT then go_to @history.forward

      when      Curses::Key::END   then @display.scroll_bottom
      when      Curses::Key::HOME  then @display.scroll_top
      when 'j', Curses::Key::DOWN  then @display.scroll_down
      when 'k', Curses::Key::UP    then @display.scroll_up
      when ' ', Curses::Key::NPAGE then @display.page_down
      when      Curses::Key::PPAGE then @display.page_up

      when 'h' then
        display @history.list, nil
      when 'i' then
        @message.show "pos: #{@history.position} items: #{@history.pages.length}"

      when 'Q', 3, 4 then break # ^C, ^D
      when      26, Curses::Key::SUSPEND then
        Curses.close_screen
        Process.kill 'STOP', $$

      when 'g' then display_name @message.prompt

      else
        @message.error "unknown key #{key.inspect}"
      end
    end
  end

  def find_module_named name
    found = @stores.map do |store|
      store.cache[:modules].find_all { |m| m == name }
    end.flatten.uniq

    not found.empty?
  end

  def go_to page
    if page then
      #raise page.inspect
      display(*page)
    else
      Curses.flash
    end
  end

  def init_color
    if Curses.start_color then
      Curses.use_default_colors
      @colors = true
      # This is a a hack.  I'm abusing the COLOR_ constants to make a color on
      # default background color pair.
      Curses.init_pair Curses::COLOR_CYAN,  Curses::COLOR_CYAN,  -1
      Curses.init_pair Curses::COLOR_GREEN, Curses::COLOR_GREEN, -1
      Curses.init_pair Curses::COLOR_WHITE, Curses::COLOR_WHITE, -1

      @link_style = Curses.color_pair(Curses::COLOR_CYAN) | Curses::A_UNDERLINE
      @hover_style =
        Curses.color_pair(Curses::COLOR_WHITE) | Curses::A_BOLD |
        Curses::A_UNDERLINE
    else
      @link_style = Curses::A_UNDERLINE
      @hover_style = Curses::A_BOLD
    end
  end

  def run
    Curses.init_screen

    init_color

    Curses.noecho
    Curses.curs_set 0 # invisible

    @message = RDoc::Curses::Message.new

    @display = RDoc::Curses::Display.new self
    @display.show HELP, nil, false

    trap_resume do
      event_loop
    end
  end

  def trap_resume
    Curses.raw
    old_cont = trap 'CONT' do Curses.doupdate end

    yield

  ensure
    Curses.noraw
    trap 'CONT', old_cont
  end

end

