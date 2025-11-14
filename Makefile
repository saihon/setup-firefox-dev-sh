NAME := setup-firefox-dev
FILE := setup-firefox-dev.sh
PREFIX := /usr/local/bin

.PHONY: all clean install uninstall

all: $(NAME)

$(NAME): $(FILE)
	@cp $(FILE) $(NAME)
	@chmod 755 $(NAME)

clean:
	$(RM) $(NAME)

install: $(NAME)
	@echo "Installing $(NAME) to $(PREFIX)"
	@install -m 755 $(NAME) $(PREFIX)

uninstall:
	@echo "Removing $(NAME) from $(PREFIX)"
	@$(RM) -f $(PREFIX)/$(NAME)