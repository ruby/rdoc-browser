##
# A Display is a Curses::Pad with functionality for scrolling and navigating
# through hyperlinks.

class RDoc::RI::Browser::Display < Curses::Pad

  ##
  # The row displayed at the top of the viewable window

  attr_reader :current_row

  ##
  # The hyperlinks in this document.  Stored as y position, x position and
  # link text.

  attr_reader :links

  ##
  # Creates a new display that communicates with +driver+

  def initialize driver
    super Curses.lines - 1, Curses.cols

    @driver = driver
    @message = driver.message

    clear
  end

  ##
  # Resets the display for showing a new page

  def clear
    @current_row = 0
    @links = []
    @current_link = -1
    setpos 0, 0

    resize 0, Curses.cols

    super

    noutrefresh
  end

  ##
  # The content of the highlighted hyperlink.  If the user has not selected a
  # hyperlink nil is returned.

  def current_link
    return nil if @current_link == -1

    @links[@current_link].last
  end

  ##
  # Advance to the next hyperlink and scroll the display appropriately.
  #
  # This will wrap to the beginning when advancing past the last link in the
  # document.

  def next_link
    return if @links.empty?

    write_link @current_link, @driver.link_style

    @current_link += 1
    @current_link = 0 if @current_link >= @links.length

    write_link @current_link, @driver.hover_style

    scroll_to @links[@current_link].first
  end

  ##
  # Number of rows in the document

  alias rows maxy

  ##
  # Scrolls down one page

  def page_down
    @current_row += Curses.lines - 1

    noutrefresh
  end

  ##
  # Scrolls up one page

  def page_up
    @current_row -= Curses.lines - 1

    noutrefresh
  end

  ##
  # Retreat to the previous hyperlink and scroll the display appropriately.
  #
  # This will wrap to the end when retreating past the first link in the
  # document.

  def previous_link
    return if @links.empty?

    write_link @current_link, @driver.link_style

    @current_link -= 1
    @current_link = @links.length - 1 if @current_link < 0

    write_link @current_link, @driver.hover_style

    scroll_to @links[@current_link].first
  end

  ##
  # screen_position is used to refresh the display for the currently selected
  # row and screen size.

  def screen_position
    @current_row = 0       if @current_row < 0
    @current_row = max_row if @current_row > max_row

    [@current_row, 0, 0, 0, Curses.lines - 2, Curses.cols]
  end

  ##
  # Scrolls to the end of the document

  def scroll_bottom
    @current_row = max_row

    noutrefresh
  end

  ##
  # Scrolls down one row

  def scroll_down
    @current_row += 1

    noutrefresh
  end

  ##
  # Scrolls to the row +row+

  def scroll_to row
    height = Curses.lines - 2

    if row < @current_row then
      @current_row = row
    elsif row > @current_row + height then
      @current_row = row
    end

    noutrefresh
  end

  ##
  # Scrolls to the beginning of the document

  def scroll_top
    @current_row = 0

    noutrefresh
  end

  ##
  # Scrolls up one row

  def scroll_up
    @current_row -= 1

    noutrefresh
  end

  ##
  # Changes the displayed document to +content+.  +context+ is used for
  # generating hyperlinks in +content+.  If you don't wish hyperlinks to
  # appear set +crossref+ to false

  def show content, context, crossref = true
    clear

    formatter = RDoc::Markup::ToCurses.new self, crossref, context, @driver

    formatter.convert content

    noutrefresh
  end

  ##
  # The maximum scrollable row.

  def max_row
    maxy - Curses.lines + 1
  end

  def noutrefresh # :nodoc:
    super(*screen_position)
  end

  def refresh # :nodoc:
    super(*screen_position)
  end

  ##
  # Writes the hyperlink at +index+ with +style+

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

