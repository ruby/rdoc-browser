require 'minitest/unit'
require 'rdoc/markup/text_formatter_test_case'
require 'rdoc/ri/browser'
require 'rdoc/markup/to_curses'

class TestRDocMarkupToCurses < RDoc::Markup::TextFormatterTestCase

  ONE_LINE = 'one two three four five six seven eight nine ten'
  MULTI_LINE = <<-MULTI_LINE.split("\n").join ' '
one two three four five six seven eight nine ten eleven twelve thirteen
fourteen fifteen sixteen seventeen eighteen nineteen twenty
  MULTI_LINE

  class Window

    attr_accessor :curx
    attr_accessor :cury

    attr_accessor :str

    attr_accessor :maxy
    attr_accessor :maxx

    def initialize
      @curx = 0
      @cury = 0

      @maxx = 80
      @maxy = 25

      @str = ''
    end

    def << str
      @str << str
    end

  end

  module Curses
    A_BOLD = 0
    A_NORMAL = 0
    A_UNDERLINE = 0
    COLOR_GREEN = 0

    def self.cols() 80 end
    def self.color_pair(*) 0 end
  end

  def setup
    super

    @window = Window.new

    @to = RDoc::Markup::ToCurses.new @window, nil, nil, nil
  end

  def test_wrap
    @to.start_accepting

    text = MULTI_LINE.dup

    @to.wrap text

    expected = <<-EXPECTED.chomp
one two three four five six seven eight nine ten eleven twelve thirteen
fourteen fifteen sixteen seventeen eighteen nineteen twenty
    EXPECTED

    assert_equal expected, @to.window.str
  end

  def test_wrap_indent
    @to.start_accepting
    @to.indent = 2

    text = MULTI_LINE.dup

    @to.wrap text

    expected = <<-EXPECTED.chomp
  one two three four five six seven eight nine ten eleven twelve thirteen
  fourteen fifteen sixteen seventeen eighteen nineteen twenty
    EXPECTED

    assert_equal expected, @to.window.str
  end

  def test_wrap_indent_prefix
    @to.start_accepting
    @to.indent = 2
    @to.prefix = '* '

    text = MULTI_LINE.dup

    @to.wrap text

    expected = <<-EXPECTED.chomp
* one two three four five six seven eight nine ten eleven twelve thirteen
  fourteen fifteen sixteen seventeen eighteen nineteen twenty
    EXPECTED

    assert_equal expected, @to.window.str
  end

  def test_wrap_first_line
    @to.start_accepting
    @window.curx = 40

    text = ONE_LINE.dup

    out = @to.wrap_first_line text, 78, ''

    assert_equal ['one two three four five six seven', "\n", ''], out
    assert_equal 'eight nine ten', text
  end

  def test_wrap_first_line_next_prefix
    @to.start_accepting
    @window.curx = 40

    text = ONE_LINE.dup

    out = @to.wrap_first_line text, 78, '* '

    assert_equal ['one two three four five six seven', "\n", '* '], out
    assert_equal 'eight nine ten', text
  end

  def test_wrap_first_line_short
    @to.start_accepting
    @window.curx = 29

    text = ONE_LINE.dup

    out = @to.wrap_first_line text, 78, '* '

    assert_nil out
    assert_equal 'one two three four five six seven eight nine ten', text
  end

end

class RDoc::Markup::ToCurses
  Curses = TestRDocMarkupToCurses::Curses
end

