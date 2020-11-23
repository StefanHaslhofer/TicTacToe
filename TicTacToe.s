
	# PURPOSE:  This program lets you play Tic-Tac-Toe
	# Two players set their mark (first: X; second: O) alternating
	# on a playing field of 3x3 fields.
	# The first one to achieve three marks in a column, row, or
	# diagonal wins.
	# The program prints the current field after each move.
	# Setting a piece consists of entering the number of the field
	# to set the mark: Top-left is 1, top-right is 3, middle-left is 4
	# and bottom right is 9 (like a telephone pad).
	# The program checks:
	# * Is the move "0"? Then the game ends prematurely.
	# * Is the move valid, i.e. is the number is valid and
	#   the field still free? If not, an error message is
	#   printed and the player can enter their move again.
	#   \r and \n are ignored on reading and do not produce an error.
	# * Does this player win by this move? If yes, a message is printed
	#   and the game ends.
	# * Is there another field empty, so the next player may move?
	#   If not the game ends in a draw.
	# The exit value of the program is -2 in case of any error,
	# -1 if the game was prematurely terminated, 0 in case of a draw,
	# or 1/2 dependent on who won the game

	# VARIABLES: The registers have the following uses:
	#
	# %rbx - stores the game exit codes
	# %r8 - number of moves
	# %r9 - stores the user input
	# %r10 - row count for output
	# %r12 - element counter for print row loop
	# %r13 - used for searching for the question mark and later stores field value which is written to buffer for output
	# %r14 - store the current player
	# %r15 - stores the current player character for indirect access to buffer
	#
	# The following memory locations are used:
	#
	# field:	Playing field - an array/list of 9 characters
	# player_number_offset_prompt: Offset in string enter_move of the question mark
	# player_number_offset_wins: Offset in string player_wins of the question mark
	# ..............
	#

	.equ MARK1,'X'
	.equ MARK2,'O'

	# System call numbers
	.equ SYS_OPEN, 2
	.equ SYS_READ, 0
	.equ SYS_WRITE, 1
	.equ SYS_CLOSE, 3
	.equ SYS_EXIT, 60

	.equ STDIN,  0
	.equ STDOUT, 1
	.equ STDERR, 2

	# Options for open   (look at /usr/include/asm/fcntl.h for
	#                    various values.  You can combine them
	#                    by adding them)
	.equ O_RDONLY, 0                  # Open file options - read-only
	.equ O_CREAT_WRONLY_TRUNC, 01101  # Open file options - these options are:
	                                  # CREAT - create file if it doesn't exist
	                                  # WRONLY - we will only write to this file
	                                  # TRUNC - destroy current file contents, if any exist

	.equ O_PERMS, 0666                # Read & Write permissions for everyone

	# End-of-file result status
	.equ END_OF_FILE, 0  # This is the return value of read() which
	                     # means we've hit the end of the file

#.....................

	.section .data
field: .byte 0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 # Playing field; initialized with spaces

sample_field:  .asciz "Field numbers:\n+---+---+---+\n+ 1 + 2 + 3 +\n+---+---+---+\n+ 4 + 5 + 6 +\n+---+---+---+\n+ 7 + 8 + 9 +\n+---+---+---+\n\n"
.set sample_field_len,.-sample_field-1	# -1 or we also print the \0 later!

h_ruler:  .asciz "+---+---+---+\n"
.set h_ruler_len,.-h_ruler-1

v_begin:  .asciz "+ "
.set v_begin_len,.-v_begin-1

v_middle: .asciz " | "
.set v_middle_len,.-v_middle-1

v_end:    .asciz " +\n"
.set v_end_len,.-v_end-1

enter_move: .asciz "Please enter your move, player ?: "
.set enter_move_len,.-enter_move-1
player_number_offset_prompt: .quad 0	# Should be 31

invalid_field: .asciz "Invalid field number\n"
.set invalid_field_len,.-invalid_field-1

field_full: .asciz "Field already occupied\n"
.set field_full_len,.-field_full-1

player_wins: .asciz "Player ? wins! Congratulations!\n"
.set player_wins_len,.-player_wins-1
player_number_offset_wins: .quad 0	# Should be 7

end_draw: .asciz "The game ends in a draw - try again!\n"
.set end_draw_len,.-end_draw-1

linebreak: .asciz "\n"
.set linebreak_len,.-linebreak-1

.section .bss           # create buffer for stdin from file
	.equ BUFFER_SIZE, 1
	.lcomm BUFFER_DATA, BUFFER_SIZE

.section .text

.global _start
_start:
    movq $0,%r8       # number of moves
    movq $0,%r13

# search question mark in strings
player_number_offset_prompt_search:
                                                # (note: i don´t handle the case that there is no ?, because it´s given by definition)
    cmpb $'?',enter_move(,%r13,1)               # compare string at current index with ?
    je set_player_number_offset_prompt          # end loop and set player_number
    incq %r13                                   # next index
    cmpq $enter_move_len,%r13                   # compare string length to current index
    jl player_number_offset_prompt_search       # next iteration if r13 is lower than the string length

set_player_number_offset_prompt:
    movq %r13,player_number_offset_prompt

    movq $0,%r13

# search question mark in strings
player_number_offset_wins_search:
                                                # (note: i don´t handle the case that there is no ?, because it´s given by definition)
    cmpb $'?',player_wins(,%r13,1)               # compare string at current index with ?
    je set_player_number_offset_wins            # end loop and set player_number
    incq %r13                                   # next index
    cmpq $player_wins_len,%r13                   # compare string length to current index
    jl player_number_offset_wins_search       # next iteration if r13 is lower than the string length

set_player_number_offset_wins:
    movq %r13,player_number_offset_wins

print_initial_field:
    # print the sample field
	movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $sample_field,%rsi	        # print sample field
	movq $sample_field_len,%rdx	    # length of string
	movq $STDOUT,%rax		        # write to stream
	syscall

    movq $3,%rbx        # initiate game with state 3 (running)
    movq $0, %r14       # start with playernumber zero

game_loop:
    incq %r14           # immediatly increase to playernumber one

error_reentry:
	subq $8,%rsp		# ensure stack alignment
	movq %r14,%rdi        # push playernumber as a paremeter to the stack
	call player_move    # call output function for player move
	addq $8,%rsp        # clean up stack parameters
	addq $8,%rsp        # clean up alignment space

    cmpq $0,%rax    # end execution if rax has ascii value of zero
    je set_termination_code_and_end

    cmpq $-1,%rax       # ignore input if \n
    je error_reentry    # repeat the current input if value is ignored

    cmpq $-2,%rax   # print error message and repeat
    je print_invalid_field

    subq $8,%rsp		# ensure stack alignment
	movq %rax,%rdi      # push entered fieldnumber as a paremeter to the stack
	movq %r14,%rsi      # push entered fieldnumber as a paremeter to the stack
    call play_round     # call function for win calculation
    addq $16,%rsp        # clean up stack parameters
	addq $8,%rsp         # clean up alignment space

	movq %rax,%rbx      # the return value of play_rounf represents the game status which is saved in rbx

	movq $0,%r10

	# print linebreak
	movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $linebreak,%rsi	        # print linebreak
	movq $linebreak_len,%rdx	    # length of string
	syscall

print_field:
    # print the top ruler
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $h_ruler,%rsi	        # print top ruler
	movq $h_ruler_len,%rdx	    # length of string
	syscall

print_round_loop:
	# print the row begin
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $v_begin,%rsi	        # print row begin
	movq $v_begin_len,%rdx	    # length of string
	syscall

	movq $0,%r12                # set element count to 0

print_row_loop:
    movq $0,%rsi                    # empty rsi
    movq $BUFFER_DATA,%r15          # write buffer address into r15
    movb field(,%r10,1),%r13b       # store field value in r13 to write it to buffer late
    movq %r13,(%rsi,%r15,1)         # write the field value into the buffer

    # print a field element
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $BUFFER_DATA,%rsi	        # print the field at current field index
	movq $BUFFER_SIZE,%rdx	        # length of string
	movq $STDOUT,%rax		        # write to stream
	syscall

	incq %r12                       # increment row element count
	incq %r10                       # increment row count
	cmpq $3,%r12                    # check if element is last in row
	je print_row_end                # jump if last element of row was printed

	# print the field seperator
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $v_middle,%rsi	        # print field seperator
	movq $v_middle_len,%rdx	    # length of string
	syscall

    jmp print_row_loop

print_row_end:
    # print the row end
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $v_end,%rsi	        # print row end
	movq $v_end_len,%rdx	    # length of string
	syscall

    # print the bottom ruler
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $h_ruler,%rsi	        # print bottom ruler
	movq $h_ruler_len,%rdx	    # length of string
	syscall

	cmpq $9,%r10
	jl print_round_loop

	# print linebreak
	movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $linebreak,%rsi	        # print linebreak
	movq $linebreak_len,%rdx	    # length of string
	syscall

    cmpq $2, %r14       # when player two finished turn -> reset playerno
                        # when player one finished turn -> do nothing beacause playerno get increased in next iteration
    jne no_player_switch    # when it´s player one´s turn (playernumber != 2) we don´t reset the player number

    movq $0, %r14       # reset player number to zero if player two finishes his turn

no_player_switch:
    incq %r8            # increment move count

    cmpq $0,%rbx                # check if there game status changed
    jg print_winner_message     # status greater 0 means someone has won the game

	cmpq $9,%r8        # check if game is still running
	jl game_loop         # restart game loop if game state is running

# nobody has won after every field is occupied (draw)
print_draw_message:
    # print draw
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $end_draw,%rsi	        # print draw
	movq $end_draw_len,%rdx	    # length of string
	syscall
	jmp end                     # end game after printing draw message

print_winner_message:
    movq player_number_offset_wins,%r13
    addq $48,%rbx                    # add 48 to palyernumber to get the ascii value of the number
    movb %bl,player_wins(,%r13,1)   # change ? to player number at index r13
    subq $48,%rbx                   # subtract the 48 again because we need the number itself for status code

    # print the winner
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $player_wins,%rsi	        # print winner
	movq $player_wins_len,%rdx	    # length of string
	syscall
	jmp end                         # end game after printing the winner

print_invalid_field:
    # print invalid field
    movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $invalid_field,%rsi	        # print invalid field
	movq $invalid_field_len,%rdx	    # length of string
    syscall

    jmp error_reentry

set_termination_code_and_end:
    movq $-1,%rbx
    jmp end


# -----------------------------------------------------------------------

   # PURPOSE:  This function prints the board each round and checks the game state
   #
   # INPUT:    player number and input number
   #
   # OUTPUT:   game state
   #
   # VARIABLES:
   #          %rax - store system call number and return value
   #          %rdi - first parameter
   #          %rsi - second parameter
   #          %r12 - stores the field number the user wants to tick and later use it for row tick counter
   #          %r13 - current player number
   #          %r14 - store current player character (X or O)
   #          %rcx - number of field
   #          %r9  - stores the row number (1 - 3)
   #          %r10 - stores field number of a row (1 - 3)

   .type play_round, @function
play_round:
    pushq %rbp           # store old base pointer
	movq  %rsp,%rbp      # create mew base pointer
	subq $32,%rsp        # reserve space for four variables
    pushq %r12
    pushq %r13
    pushq %r14

    movq %rdi,%r12          # store the fieldnumber in r12
    decq %r12               # decrement to start at index 0

    movq %rsi,%r13          # store the playernumber in r13

    movb $MARK1,field(,%r12,1)    # write a X into the field
    movq $MARK1,%r14            # set r14 to player character of player 1
    cmpq $1,%r13                # don´t overwrite X with 0 if playernumber is 1
    je ignore_overwrite

    movb $MARK2,field(,%r12,1)      # replace the X with a O into the field if it´s player two´s turn
    movq $MARK2,%r14                # set r14 to player character of player 2

ignore_overwrite:

    movq $-1,%r9            # set field counter to -1
    movq $0,%r10            # set row counter to 0
    movq $0,%rax            # set return value to 0, which means nobody has won yet (or draw)
    movq $-1,%r12            # empty r12

check_field_row:           # check the rows
    incq %r9
    cmpq $3,%r10           # if the row count reaches the value 3 the player has all elements in a row and therefore won
    je player_won          # jump to palyer_won if equals
    incq %r10              # increment field number count

    cmpb %r14b,field(,%r9,1)     # compare the player character to the character at the current index in the field
    je check_field_row              # check next field if character equals player character
                                # otherwise the row cannot be won
    addq $3,%r12             # increment field count by 3 (next row)
    movq %r12,%r9            # set r9 to a multiple of three beacuse if an element in a row is different from the player´s cahracter
                             # the rest of the row should be ignored

    movq $0,%r10                # reset the row counter to 0 for next row iteration

    cmpq $8, %r9                # if field index = 8 the field has not been won jet
    jne check_field_row          # if field index < 8 there is yet another row to check

    movq $0,%r9            # set field counter to 0
    movq $0,%r10           # set row counter to 0

check_field_column:             # check the columns
    movq %r9,%r10                # start with column index
    cmpb %r14b,field(,%r10,1)     # compare the player character to the character at the current index in the field
    jne next_column        # jump to next case if not equal the current player character
                                # if one element in column wrong -> player can´t win in this case

    addq $3,%r10                 # add 3 to switch to the same column in the next line
    cmpb %r14b,field(,%r10,1)
    jne next_column

    addq $3,%r10                 # add 3 to switch to the same column in the next line
    cmpb %r14b,field(,%r10,1)
    je player_won               # if last character in column matches the player character the player has won
                                # the other two have to be correct because otherwise the program would have jumped

next_column:
    movq %r9,%r10                # reset the row counter to 0 for next row iteration
    incq %r9                    # increment row count
    cmpq $3, %r9                # if rowcount = 3 the field has not be won jet
    jl check_field_column          # if rowcount < 3 there is yet another row to check


check_diagonal_1:               # check the first diagonal
    movq $0,%r9                 # check the left top corner
    cmpb %r14b,field(,%r9,1)
    jne check_diagonal_2        # jump to next case if not equal the current player character
                                # if one element in diagonal wrong -> player can´t win in this case

    movq $4,%r9                 # check the middle field
    cmpb %r14b,field(,%r9,1)
    jne check_diagonal_2        # jump to next case if not equal the current player character

    movq $8,%r9                 # check the right bottom corner
    cmpb %r14b,field(,%r9,1)
    je player_won               # if last character matches the player character the player has won
                                # the other two have to be correct because otherwise the program would have jumped

check_diagonal_2:               # check the second diagonal
    movq $2,%r9                 # check the top right corner
    cmpb %r14b,field(,%r9,1)
    jne end_player_round        # jump to next case if not equal the current player character
                                # if one element in diagonal wrong -> player can´t win in this case

    movq $4,%r9                 # check the middle field
    cmpb %r14b,field(,%r9,1)
    jne end_player_round        # jump to next case if not equal the current player character

    movq $6,%r9                 # check the left bottom corner
    cmpb %r14b,field(,%r9,1)
    jne end_player_round        # if last character matches the player character the player has won
                                # simply let the program run through because status won is set in next iteration

player_won:
    movq %r13, %rax               # set return value to 1 which implies victory

end_player_round:
    popq %r14
    popq %r13
    popq %r12
	addq $32,%rsp
    movq %rbp, %rsp         # destroy local variables
    popq %rbp;              # restore base pointer
	ret
# -----------------------------------------------------------------------

   # PURPOSE:  This function is used to print the playernumber
   #           of the current player and returns his move
   #
   # INPUT:    First argument - the player number
   #
   # OUTPUT:   Will give the field as return value
   #
   # VARIABLES:
   #          %rax - store system call number and return value
   #          %rdi - string to print and first parameter
   #          %rdx - length of string to print
   #          %r12 - stores the palyer number and is used to check if input is valid
   #          %r13 - index count of string to get current character

   .type print_player_move, @function
player_move:
    pushq %rbp           # store old base pointer
	movq  %rsp,%rbp      # create mew base pointer
	subq $32,%rsp        # reserve space for four variables
    pushq %r12
    pushq %r13

    movq %rdi,%r12       # store the playernumber in r12
    movq player_number_offset_prompt,%r13
set_player_number:
    addq $48,%r12                    # add 48 to palyernumber to get the ascii value of the number
    movb %r12b,enter_move(,%r13,1)   # change ? to player number at index r13

	# read player input
	movq $STDIN,%rdi		        # file descriptor of STDIN
	movq $BUFFER_DATA,%rsi	        # print string with playernumber
	movq $BUFFER_SIZE,%rdx	                # length of string
	movq $STDIN,%rax		        # write to stream
	syscall                 # size of buffer read is returned in %rax

    cmpq $END_OF_FILE, %rax       # Check for end of file marker
	je end                   # If found (or error), go to the end

	movq $0,%rax            # empty rax
	movq $-1,%rax           # we need to check if input is correct
	movb (%rsi),%r12b       # store the first byte of rsi in r12

	cmpb $10,%r12b          # ignore \n
	je return_move

	cmpb $13,%r12b          # ignore \r
	je return_move

	# print enter move request
    # we print after input because we have to check if the input is valid
	movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $enter_move,%rsi	        # print string with playernumber
	movq $enter_move_len,%rdx	    # length of string
	movq $STDOUT,%rax		        # write to stream
	syscall

	movq $0,%rax            # empty rax
	movq $-2,%rax           # we need to check if input is correct

	movq %r12,%r13                      # store inupt in r13
	subq $48,%r13                       # number of input
	cmpq $0,%r13                        # rjump to end if value is zero
	je set_return_value

	movq %r12,%r13                      # store inupt in r13
	subq $49,%r13                       # get the ascii value of input to get an index
    cmpb $0x20,field(,%r13,1)           # compare field at index of input number (the element we want to write to) with ascii value of blank
    jne return_move                     # wrong input if field has already been set by a player
                                        # keep status -2 (error) and return

	cmpb $48,%r12b              # compare r12 with ascii value of 0
    jl return_move              # wrong input if entered value is bellow 0 in ascii table
                                # keep status -2 (error) and return

    cmpb $57,%r12b              # compare r12 with ascii value of 9
    jg return_move              # wrong input if entered value is greater than 9 in ascii table
                                # keep status -2 (error) and return

set_return_value:
    movq $0,%rax            # empty rax
	movb %r12b,%al         # set the move entered by the player as return value
    sub $48, %al          # subtract the offset of the first number (0) of the ascii table
                            # beacuse stdin returns ascii values

return_move:
    popq %r13
    popq %r12
    addq $32,%rsp
    movq %rbp, %rsp         # destroy local variables
    popq %rbp;              # restore base pointer
    ret                     # return to calling function

end:
    # print last linebreak
	movq $STDOUT,%rdi		        # file descriptor of STDOUT
	movq $STDOUT,%rax		        # write to stream
	movq $linebreak,%rsi	        # print linebreak
	movq $linebreak_len,%rdx	    # length of string
	syscall

	movq $SYS_EXIT, %rax
	movq %rbx, %rdi          # return status
	syscall
