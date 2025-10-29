FROM alpine:3.19.1

LABEL AboutImage "Alpine_Chromium_NoVNC"

LABEL Maintainer "Israel Alagbe <israel.alagbe@gmail.com>"

#VNC Server Password
ARG VNC_PASS=CHANGE_IT
ENV	VNC_PASS=${VNC_PASS} \
#VNC Server Title(w/o spaces)
	VNC_TITLE="Chromium" \
#VNC Resolution(720p is preferable)
	VNC_RESOLUTION="1280x720" \
#VNC Shared Mode
	VNC_SHARED=false \
#Local Display Server Port
	DISPLAY=:0 \
#NoVNC Port
	NOVNC_PORT=$PORT \
	PORT=8080 \
#Chrome Remote Debugging Port
	DEBUG_PORT=9222 \
#Heroku No-Sleep Mode
	NO_SLEEP=false \
#Locale
	LANG=en_US.UTF-8 \
	LANGUAGE=en_US.UTF-8 \
	LC_ALL=C.UTF-8 \
	TZ="Africa/Lagos"

COPY assets/ /

RUN	apk update && \
	apk add --no-cache tzdata ca-certificates supervisor curl wget openssl bash python3 py3-requests sed unzip xvfb x11vnc websockify openbox chromium nss alsa-lib font-noto font-noto-cjk nodejs npm && \
# noVNC SSL certificate
	openssl req -new -newkey rsa:4096 -days 36500 -nodes -x509 -subj "/C=IN/O=Dis/CN=www.google.com" -keyout /etc/ssl/novnc.key -out /etc/ssl/novnc.cert > /dev/null 2>&1 && \
# Install Node.js dependencies for Express proxy
	cd /server && npm install && \
# TimeZone
	cp /usr/share/zoneinfo/$TZ /etc/localtime && \
	echo $TZ > /etc/timezone && \
# Wipe Temp Files
	apk del build-base curl wget unzip tzdata openssl && \
	rm -rf /var/cache/apk/* /tmp/*

# Expose NoVNC, Chrome Remote Debugging, and Express Proxy ports
EXPOSE $PORT $DEBUG_PORT 30001

ENTRYPOINT ["supervisord", "-l", "/var/log/supervisord.log", "-c"]

CMD ["/config/supervisord.conf"]
