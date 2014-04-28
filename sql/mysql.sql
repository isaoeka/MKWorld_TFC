DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS worlds;
DROP TABLE IF EXISTS stages;
DROP TABLE IF EXISTS user_worlds;
DROP TABLE IF EXISTS po_historys;
DROP TABLE IF EXISTS shogos;

CREATE TABLE IF NOT EXISTS users (
	id int unsigned NOT NULL AUTO_INCREMENT,  
	name char(32) NOT NULL UNIQUE,  
	apikey char(32) NOT NULL,  
	shogo_id int NOT NULL,  
	exp int NOT NULL,  
	twitter_id char(32),  
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS worlds (
	id int unsigned NOT NULL,  
	name text NOT NULL,  
	PRIMARY KEY (id)
) ENGINE=InnoDb DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS stages (
	id int unsigned NOT NULL,
	world_id int NOT NULL,  	
	name text NOT NULL,  
	latitude decimal(9, 6) NOT NULL,  
	longitude decimal(9, 6) NOT NULL,  
	zoom int NOT NULL, 
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS user_worlds (
	user_id int NOT NULL,  
	world_id int NOT NULL,  
	stage_id int NOT NULL,  	
	map_percentage decimal(6, 3) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS po_historys (
	user_id int NOT NULL,  
	world_id int NOT NULL,
    	stage_id int NOT NULL,  	
	radius int NOT NULL,  
	latitude decimal(9, 6) NOT NULL, 
	longitude decimal(9, 6) NOT NULL,  
	timestamp TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8; 

CREATE TABLE IF NOT EXISTS shogos (
	id int NOT NULL,  
	name text NOT NULL,  
	PRIMARY KEY (id)
) ENGINE=InnoDb DEFAULT CHARSET=utf8;
