module Lrama
  class Grammar
    class ParameterizingRules
      class Builder
        # Builder for option of general parameterizing rules
        class Option < Base

          # program: option(number)
          #
          # =>
          #
          # program: option_number
          # option_number: ε
          # option_number: number
          def build
            validate_argument_number!

            rules = []
            @build_token = Lrama::Lexer::Token::Ident.new(s_value: "option_#{@token.s_value}")
            rules << Rule.new(id: @rule_counter.increment, _lhs: @build_token, _rhs: [], token_code: @user_code, precedence_sym: @precedence_sym, lineno: @line)
            rules << Rule.new(id: @rule_counter.increment, _lhs: @build_token, _rhs: [@token], token_code: @ser_code, precedence_sym: @precedence_sym, lineno: @line)
            rules
          end
        end
      end
    end
  end
end
