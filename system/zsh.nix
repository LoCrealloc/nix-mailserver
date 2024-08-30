{	pkgs, ... } : {
	programs.zsh = {
		enable = true;

		ohMyZsh = {
			enable = true;
			theme = "agnoster";
		};
	};

	users.defaultUserShell = pkgs.zsh;
}
