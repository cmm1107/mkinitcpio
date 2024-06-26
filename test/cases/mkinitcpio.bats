#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-2.0-only

bats_load_library 'bats-assert'
bats_load_library 'bats-support'
load "../helpers/common"

@test "test reproducible builds for initramfs" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    local tmpdir
    tmpdir="$(mktemp -d --tmpdir="$BATS_RUN_TMPDIR" "${BATS_TEST_NAME}.XXXXXX")"

    echo "HOOKS=(base)" >> "$tmpdir/mkinitcpio.conf"

    run ./mkinitcpio \
        -D "${PWD}" \
        -c "$tmpdir/mkinitcpio.conf" \
        -g "$tmpdir/initramfs-1.img"

    run ./mkinitcpio \
        -D "${PWD}" \
        -c "$tmpdir/mkinitcpio.conf" \
        -g "$tmpdir/initramfs-2.img"

    cmp "$tmpdir/initramfs-1.img" "$tmpdir/initramfs-2.img"
}

@test "test reproducible builds for uki" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    local tmpdir
    tmpdir="$(mktemp -d --tmpdir="$BATS_RUN_TMPDIR" "${BATS_TEST_NAME}.XXXXXX")"

    echo "HOOKS=(base)" >> "$tmpdir/mkinitcpio.conf"

    ./mkinitcpio \
        -D "${PWD}" \
        -c "$tmpdir/mkinitcpio.conf" \
        --uki "$tmpdir/uki-1.efi"

    ./mkinitcpio \
        -D "${PWD}" \
        -c "$tmpdir/mkinitcpio.conf" \
        --uki "$tmpdir/uki-2.efi"

    sha256sum "$tmpdir/uki-1.efi" "$tmpdir/uki-2.efi"
    cmp "$tmpdir/uki-1.efi" "$tmpdir/uki-2.efi"
}

@test "test creating UKI with no cmdline" {
    bats_require_minimum_version 1.5.0
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip 'No kernel modules available'
    fi

    local tmpdir
    tmpdir="$(mktemp -d --tmpdir="$BATS_RUN_TMPDIR" "${BATS_TEST_NAME}.XXXXXX")"

    printf '%s\n' 'HOOKS=(base)' > "${tmpdir}/mkinitcpio.conf"

    ./mkinitcpio \
        -D "${PWD}" \
        -c "${tmpdir}/mkinitcpio.conf" \
        --uki "${tmpdir}/uki.efi" --no-cmdline

    run objdump -j .uname -s "${tmpdir}/uki.efi"
    run -1 objdump -j .cmdline -s "${tmpdir}/uki.efi"
}

@test "test early cpio creation" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    local tmpdir
    tmpdir="$(mktemp -d --tmpdir="$BATS_RUN_TMPDIR" "${BATS_TEST_NAME}.XXXXXX")"

    echo "HOOKS=(base test)" >> "$tmpdir/mkinitcpio.conf"
    install -dm755 "$tmpdir/install"
    cat << EOH >> "$tmpdir/install/test"
#!/usr/bin/env bash
build() {
    echo "this is a test" > "\${EARLYROOT}/some_file"
}
EOH

    run ./mkinitcpio \
        -D "${PWD}" -D "$tmpdir" \
        -c "$tmpdir/mkinitcpio.conf" \
        -g "$tmpdir/initramfs.img"

    assert_output --partial '-> Early uncompressed CPIO image generation successful'
}

@test "test moving compressed files to early cpio" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    local tmpdir
    tmpdir="$(mktemp -d --tmpdir="$BATS_RUN_TMPDIR" "${BATS_TEST_NAME}.XXXXXX")"

    echo "HOOKS=(test) COMPRESSION=zstd" >> "$tmpdir/mkinitcpio.conf"
    install -dm755 "$tmpdir/install"
    cat << EOH >> "$tmpdir/install/test"
#!/usr/bin/env bash
build() {
    mkdir -p "\$BUILDROOT"/test/{compressed,mixed,uncompressed}
    touch "\$BUILDROOT"/test/{compressed/dummy,mixed/dummy}.zst
    touch "\$BUILDROOT"/test/{mixed/dummy,uncompressed/dummy}
}
EOH

    ./mkinitcpio \
        -D "$tmpdir" \
        -c "$tmpdir/mkinitcpio.conf" \
        -g "$tmpdir/initramfs.img"

    run ./lsinitcpio --early "$tmpdir/initramfs.img"
    assert_line 'test/compressed/dummy.zst'
    assert_line 'test/mixed/dummy.zst'
    refute_line 'test/uncompressed'

    run ./lsinitcpio --cpio "$tmpdir/initramfs.img"
    refute_line 'test/compressed'
    assert_line 'test/mixed/dummy'
    assert_line 'test/uncompressed/dummy'
    refute_output --regexp '.*\.zst$'
}

@test "image creation zstd" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio zstd
}

@test "image creation gzip" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio gzip
}

@test "image creation bzip2" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio bzip2
}

@test "image creation lzma" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio lzma
}

@test "image creation xz" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio xz
}

@test "image creation lzop" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio lzop
}

@test "image creation lz4" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio lz4
}

@test "image creation uncompressed" {
    if [[ ! -d "/lib/modules/$(uname -r)/" ]]; then
        skip "No kernel modules available"
    fi

    __gen_test_initcpio cat
}
