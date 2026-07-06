extends GutTest
## Alive Stride 2: EventScript tokenizer/parser — pure, no scene tree.

func test_parses_simple_command_with_no_args() -> void:
	var result := EventScript.parse_line("end")
	assert_eq(result["cmd"], "end")
	assert_eq((result["args"] as Array).size(), 0)


func test_parses_command_with_plain_args() -> void:
	var result := EventScript.parse_line("move alden 10 7 walk")
	assert_eq(result["cmd"], "move")
	assert_eq(result["args"], ["alden", "10", "7", "walk"])


func test_parses_quoted_string_as_single_token() -> void:
	var result := EventScript.parse_line("speak alden \"Ah — you made it.\"")
	assert_eq(result["cmd"], "speak")
	assert_eq(result["args"], ["alden", "Ah — you made it."])


func test_quoted_string_preserves_internal_whitespace() -> void:
	var result := EventScript.parse_line("toast \"Something in Emberhollow   just got better.\"")
	assert_eq(result["args"][0], "Something in Emberhollow   just got better.")


func test_question_command_parses_two_label_choice_pairs() -> void:
	var result := EventScript.parse_line(
		"question \"Well?\" label_a \"Yes\" label_b \"No\"")
	assert_eq(result["cmd"], "question")
	assert_eq(result["args"], ["Well?", "label_a", "Yes", "label_b", "No"])


func test_unterminated_quote_consumes_to_end_of_line_without_crashing() -> void:
	var result := EventScript.parse_line("speak alden \"unterminated line")
	assert_eq(result["cmd"], "speak")
	assert_eq(result["args"][1], "unterminated line")


func test_empty_line_parses_to_blank_command() -> void:
	var result := EventScript.parse_line("")
	assert_eq(result["cmd"], "")
	assert_eq((result["args"] as Array).size(), 0)


func test_whitespace_only_line_parses_to_blank_command() -> void:
	var result := EventScript.parse_line("    ")
	assert_eq(result["cmd"], "")


func test_extra_whitespace_between_tokens_is_collapsed() -> void:
	var result := EventScript.parse_line("bond   garrick    50")
	assert_eq(result["args"], ["garrick", "50"])


func test_parse_processes_a_full_script_array_in_order() -> void:
	var script: Array = ["label start", "wait 1.0", "jump start", "end"]
	var parsed := EventScript.parse(script)
	assert_eq(parsed.size(), 4)
	assert_eq(parsed[0]["cmd"], "label")
	assert_eq(parsed[0]["args"], ["start"])
	assert_eq(parsed[1]["cmd"], "wait")
	assert_eq(parsed[1]["args"], ["1.0"])
	assert_eq(parsed[2]["cmd"], "jump")
	assert_eq(parsed[3]["cmd"], "end")


func test_command_names_are_case_sensitive_as_written() -> void:
	var result := EventScript.parse_line("END")
	assert_eq(result["cmd"], "END")  # caller (_dispatch) decides what to do with an unknown-cased command
