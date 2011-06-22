require 'curses'
require 'rdoc'
require 'rdoc/ri/driver'
require 'rdoc/markup/to_curses'

class RDoc::RI::Browser < RDoc::RI::Driver

  ##
  # The version of rdoc-browser you are using

  VERSION = '1.0'

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
    @history = RDoc::RI::Browser::History.new
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

    @message = RDoc::RI::Browser::Message.new

    @display = RDoc::RI::Browser::Display.new self
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

require 'rdoc/ri/browser/display'
require 'rdoc/ri/browser/history'
require 'rdoc/ri/browser/message'
