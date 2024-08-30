{ config, pkgs, ... }:
{
  services.postgresql = {
    enable = true;

    ensureDatabases = [ "vmail" ];
    ensureUsers = [
      {
        name = "vmail";
        ensureDBOwnership = true;
      }
    ];

    authentication = ''
      #type 	database 	user 				origin-address 	auth-method
      local		vmail 		vmail 											peer map=vmailusers
    '';

    identMap = ''
      vmailusers postfix 	vmail
      vmailusers dovecot2 	vmail
    '';

  };
  systemd.services.postgresql.postStart =
    let
      queries = pkgs.writeText "postgres-start-queries" ''
                CREATE TYPE policy AS ENUM (
                	'none',
                	'may',
                	'encrypt',
                	'dane',
                	'dane-only',
                	'fingerprint',
                	'verify',
                	'secure'
                );

                CREATE OR REPLACE FUNCTION checksendonly(pusername character varying, pdomain character varying) RETURNS character varying
                LANGUAGE plpgsql
                AS $$
                DECLARE
                 sendonly_check boolean;
                BEGIN
                SELECT INTO sendonly_check sendonly FROM accounts WHERE username=pUsername AND domain=pDomain AND enabled=true LIMIT 1;
                IF sendonly_check=true THEN
                		RETURN 'REJECT';
                ELSE
                RETURN 'OK';
                END IF;
                END;
                $$;

                CREATE TABLE IF NOT EXISTS domains (
                	id INTEGER PRIMARY KEY,
                	domain VARCHAR(255) UNIQUE NOT NULL
                );

                CREATE TABLE IF NOT EXISTS accounts (
                	id INTEGER PRIMARY KEY,
                	username VARCHAR(64) NOT NULL,
                	domain VARCHAR(255) NOT NULL,
                	password VARCHAR(255) NOT NULL,
                	quota INTEGER DEFAULT 0,
                	enabled BOOLEAN DEFAULT false,
                	sendonly BOOLEAN DEFAULT false
                );

                CREATE TABLE IF NOT EXISTS aliases (
                	id INTEGER PRIMARY KEY,
                	source_username VARCHAR(64) NOT NULL,
                	source_domain VARCHAR(50) NOT NULL,
                	destination_username VARCHAR(64) NOT NULL,
                	destination_domain VARCHAR(255) NOT NULL,
                	enabled boolean DEFAULT false
                );

                CREATE TABLE IF NOT EXISTS tlspolicies (
                	id INTEGER PRIMARY KEY,
                	domain VARCHAR(255) UNIQUE NOT NULL,
                	policy policy NOT NULL,
                	params VARCHAR(255)
                );

        				GRANT ALL ON TABLE public.accounts TO vmail;

        				GRANT ALL ON TABLE public.aliases TO vmail;

        				GRANT ALL ON TABLE public.domains TO vmail;

        				GRANT ALL ON TABLE public.tlspolicies TO vmail;


      '';
    in
    ''
      $PSQL -d vmail -f ${queries}
    '';
}
