default: install

SwayAudioIdleInhibit_ref := "8ac8608d31e18e5a064002c2a1ef73a683ea9537"

alias f := format
alias fmt := format

format:
    just --fmt --unstable

install-SwayAudioIdleInhibit:
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install gcc-c++ git meson ninja-build pulseaudio-libs-devel wayland-devel wayland-protocols-devel
            if [ -d "SwayAudioIdleInhibit" ]; then
                git -C SwayAudioIdleInhibit fetch 
            else
                git clone https://github.com/ErikReider/SwayAudioIdleInhibit.git
            fi
            cd SwayAudioIdleInhibit
            git checkout --detach "{{ SwayAudioIdleInhibit_ref }}"
            meson setup build -Dbuildtype=release
            meson compile -C build
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install --idempotent meson
            echo "You may need to reboot and re-run to finish installation."
            mkdir --parents build
            version=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release)
            podman run \
                --arch "{{ arch() }}" \
                --interactive \
                --rm \
                --tty \
                --volume "{{ justfile_directory() }}/build:/build:Z" \
                "registry.fedoraproject.org/fedora:$version" \
                bash -c ' \
                    dnf --assumeyes install gcc-c++ git meson ninja-build pulseaudio-libs-devel wayland-devel wayland-protocols-devel \
                    && git clone https://github.com/ErikReider/SwayAudioIdleInhibit.git \
                    && cd SwayAudioIdleInhibit \
                    && git checkout --detach "{{ SwayAudioIdleInhibit_ref }}" \
                    && meson setup /build -Dbuildtype=release \
                    && meson compile -C /build
                '
        fi
    fi
    sudo install -D --target-directory=/usr/local/bin build/sway-audio-idle-inhibit
    rm --force --recursive build

install: install-SwayAudioIdleInhibit
    #!/usr/bin/env bash
    set -euxo pipefail
    distro=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
    if [ "$distro" = "fedora" ]; then
        variant=$(awk -F= '$1=="VARIANT_ID" { print $2 ;}' /etc/os-release)
        if [ "$variant" = "container" ]; then
            sudo dnf --assumeyes install gcr pre-commit
        elif [ "$variant" = "iot" ] || [ "$variant" = "sericea" ]; then
            sudo rpm-ostree install --idempotent gcr pre-commit
            echo "You may need to reboot and re-run to finish installation."
        fi
    fi
    systemctl --user enable --now gcr-ssh-agent.socket
    shell=$(basename $(getent passwd $LOGNAME | cut -d: -f7))
    if [ "$shell" = "fish" ]; then
        fish --command='set -Ux SSH_AUTH_SOCK $XDG_RUNTIME_DIR/gcr/ssh'
        fish --command='set -Ux _JAVA_AWT_WM_NONREPARENTING 1'
    elif [ "$shell" = "nu" ]; then
        nu_env_file=$(nu --commands '$nu.env-path')
        echo '$env.SSH_AUTH_SOCK = $"($env.XDG_RUNTIME_DIR)/gcr/ssh"' | tee --append "$nu_env_file"
        echo '$env._JAVA_AWT_WM_NONREPARENTING = 1' | tee --append "$nu_env_file"
    else
        echo "export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh" | tee --append "{{ home_directory() }}/.profile"
        echo "export _JAVA_AWT_WM_NONREPARENTING=1" | tee --append "{{ home_directory() }}/.profile"
        echo "Log out and back in for the updated environment variables to take effect."
    fi
    ln --force --no-dereference --relative --symbolic sway "{{ config_directory() }}/sway"
    swaymsg reload
