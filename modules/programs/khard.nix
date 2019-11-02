# khard config loader is sensitive to leading space !
{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.khard;

  vim = config.programs.vim;
  neovim = config.programs.neovim;
  emacs = config.programs.emacs;

  khardAccounts = filterAttrs (_: a: a.khard.enable)
    (config.accounts.contact.accounts);

  showYesNoBool = default: v:
         if true  ==   v then "yes"
    else if false ==   v then "no"
    else default v;

  showList = default: v:
    if isList v then concatStringsSep ", " (map default v) else default v;

  mkValueString = showYesNoBool (showList (lib.generators.mkValueStringDefault {}));
  mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } "=";


  # hack needed because khard cannot handle cmdline arguments like 'vim -d'
  difftoolVim = vimExecutable: (pkgs.writeScript "vimdiff" ''
    #!/bin/sh
    exec ${vimExecutable} -d "$@"
  '').outPath;

  vimExec = "${vim.package}/bin/vim";
  nvimExec = "${neovim.package}/bin/nvim";
  emacsExec = "${emacs.package}/bin/emacs";

in

{
  options.programs.khard = let T = lib.types; in {
    enable = mkEnableOption "khard, a CLI addressbook application";
    debug = mkEnableOption "enable debug mode";

    default_action = mkOption {
      type = T.str;
      description = "the default action if none is given on the commandline";
      default = "list";
    };
    editor = mkOption {
      type = T.str;
      description = "the editor to use with khard";
      default =
             if vim.enable    then vimExec
        else if neovim.enable then nvimExec
        else if emacs.enable  then emacsExec
        else "";
    };
    merge_editor = mkOption {
      type = T.str;
      description = "the merge editor to use with khard";
      default =
             if vim.enable    then difftoolVim vimExec
        else if neovim.enable then difftoolVim nvimExec
        else "";
    };

    table = mkOption {
      type = T.attrs;
      description = "khard config section [contact table]";
      default = {
        # display names by first or last name: first_name / last_name
        display = "first_name";
        # group by address book: yes / no
        group_by_addressbook = false;
        # reverse table ordering: yes / no
        reverse = false;
        # append nicknames to name column: yes / no
        show_nicknames = true;
        # show uid table column: yes / no
        show_uids = true;
        # sort by first or last name: first_name / last_name
        sort = "last_name";
        # localize dates: yes / no
        localize_dates = true;
        # set a comma separated list of preferred phone number types in
        # descending priority
        # or nothing for non-filtered alphabetical order
        preferred_phone_number_type = [ "pref" "cell" "home" ];
        # set a comma separated list of preferred email address types in
        # descending priority
        # or nothing for non-filtered alphabetical order
        preferred_email_address_type = [ "pref" "work" "home" ];
      };
      example = { display = "last_name"; };
    };
    vcard = mkOption {
      type = T.attrs;
      description = "khard config section [vcard]";
      default = {
        # preferred vcard version: 3.0 / 4.0
        preferred_version = "4.0";
        # Look into source vcf files to speed up search queries: yes / no
        search_in_source_files = false;
        # skip unparsable vcard files: yes / no
        skip_unparsable = false;
      };
      example = {
        # extend contacts with your own private objects
        # these objects are stored with a leading "X-" before the object name in
        # the vcard files
        # every object label may only contain letters, digits and the -
        # character
        # example:
        #   private_objects = Jabber, Skype, Twitter
        private_objects = [ "Jabber" "Skype" "Twitter" ];
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =  [ pkgs.khard ];

    xdg.configFile."khard/khard.conf".text = concatStringsSep "\n" (
    [
      "[addressbooks]"
    ]
    ++ (mapAttrsToList (name: value: concatStringsSep "\n"
      ([
        "[[${name}]]"
        "path = ${value.local.path}/"
      ]
      ++ ["\n"]
      )
      ) khardAccounts)
    ++
    [
    (generators.toINI { inherit mkKeyValue; } {
      general = { inherit (cfg) debug default_action editor merge_editor; };

      "contact table" = cfg.table;

      inherit (cfg) vcard;
    })
    ]
    );
  };
}
