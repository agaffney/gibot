# gibot

This is an IRC bot written in Perl that I originally created around 2005. It has been through many iterations
of the code (only some of which is in the git history). The bot is still running to this day, but some of his
commands no longer work.

The Docker image can be built with the following command:

$ docker build -t gibot .

You can then run it with the following command:

$ docker run -d --name gibot --restart=always -v /path/to/gibot.db:/gibot/gibot.db gibot
