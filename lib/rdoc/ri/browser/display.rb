class RDoc::RI::Browser::Display < Curses::Pad

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


