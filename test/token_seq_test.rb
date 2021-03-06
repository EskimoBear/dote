require_relative './test_helpers.rb'
require_relative '../lib/dote/token_pass.rb'

class TestTokenSeq < MiniTest::Test

  def setup
    @token_seq = Dote::TokenPass::TokenSeq.new(5) {Dote::LexemeCapture::Token.new}
  end

  def test_take_with_seq_should_succeed
    @token_seq[3].name = "target_1"
    @token_seq.last.name = "target_2"
    @token_seq.push(Dote::LexemeCapture::Token["lexeme", "name"])
    expected_seq =  @token_seq.take(@token_seq.length - 1)
    assert_equal expected_seq, @token_seq.take_with_seq("target_1", "target_2")
  end

  def test_take_with_seq_should_fail
    assert_nil @token_seq.take_with_seq("target_1", "target_2")
  end

  def test_seq_match_should_succeed
    @token_seq[1].name = "target_2"
    @token_seq[3].name = "target_1"
    @token_seq.last.name = "target_2"
    @token_seq.push(Dote::LexemeCapture::Token["lexeme", "target_2"])
    assert @token_seq.seq_match?("target_1", "target_2")
  end

  def test_seq_match_should_fail
    @token_seq[2].name = "target_1"
    @token_seq.last.name = "target_2"
    refute @token_seq.seq_match?("target_1", "target_2")
  end

end

describe Dote::TokenPass::TokenSeq do
  before do
    @lang = Dote::DoteGrammars.display_fmt
    @alternation_rule = @lang.get_rule(:sub_string)
    @concatenation_rule = @lang.get_rule(:variable_identifier)
    @token_seq = Dote::TokenPass::TokenSeq.new(4) {Dote::LexemeCapture::Token.new}
  end

  describe "#tokenize_rule" do
    it "with concatenation rule" do
      @token_seq[0].name = :variable_prefix
      @token_seq[0].lexeme = :word_1
      @token_seq[1].name = :word
      @token_seq[1].lexeme = :word_2
      @token_seq[2].name = :variable_prefix
      @token_seq[2].lexeme = :word_1
      @token_seq[3].name = :word
      @token_seq[3].lexeme = :word_2
      @token_seq.all?{|i| i.name == @concatenation_rule.name}
      @token_seq.must_be_instance_of Dote::TokenPass::TokenSeq
    end
  end
end
