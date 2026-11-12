# Environnement de test Plasma 6 pour le plasmoid PC Monitor.
# La machine de dev tourne sous Plasma 5 ; ce conteneur fournit Qt6/KF6 et
# plasmoidviewer, qui charge un plasmoid seul et remonte les erreurs QML.
FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed \
      plasma-sdk \
      plasma-workspace \
      libplasma \
      kirigami \
      noto-fonts \
      ttf-dejavu \
      dbus \
      bash \
    && pacman -Scc --noconfirm

ENV QT_QPA_PLATFORM=xcb
ENV XDG_RUNTIME_DIR=/tmp/runtime
RUN mkdir -p /tmp/runtime && chmod 700 /tmp/runtime
