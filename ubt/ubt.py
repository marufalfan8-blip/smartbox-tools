#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0 OR MIT
# -*- coding: utf-8 -*-

__license__ = "GPL-2.0"
__copyright__ = "Copyright (c) 2024, SaluteDevices"
__version__ = '0.0.1'

import argparse
import logging
import sys
from enum import Enum

from adnl import do_adnl_burn
from pyamlboot.amlimage import AmlImagePack
from pyamlboot.optimus import do_optimus_burn


class WipeFormat(Enum):
    no = 0
    normal = 1
    all = 3

    def __str__(self):
        return self.name


def main():
    logging.basicConfig(level=logging.DEBUG,
                        format='[%(asctime)s] [%(levelname)-8s]: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

    parser = argparse.ArgumentParser()
    parser.add_argument('--img',
                        required=True,
                        type=argparse.FileType('rb'),
                        help='Specify location path to aml_upgrade_package.img')
    parser.add_argument('--reset',
                        action='store_true',
                        default=False,
                        help='Reset after success')
    parser.add_argument('--no-erase-bootloader',
                        action='store_true',
                        default=False,
                        help='Skip the bootloader-erase step (OPTIMUS images only; '
                             'safer, used by the tested command)')
    parser.add_argument('--wipe',
                        type=lambda x: WipeFormat[x],
                        choices=list(WipeFormat),
                        default='normal',
                        help='Wipe mode: no, normal, or all '
                             '(all destroys every partition)')
    parser.add_argument('--password',
                        type=argparse.FileType('rb'),
                        help='Unlock usb mode using password file provided '
                             '(OPTIMUS images only)')
    parser.add_argument('--version', action='version', version=__version__)

    args = parser.parse_args()
    aml_img = AmlImagePack(args.img)
    adnl = True

    # If image contains 'usb_flow', it is ADNL
    try:
        aml_img.item_get('aml', 'usb_flow')
    except ValueError:
        adnl = False

    try:
        if adnl:
            # The ADNL flow has no separate bootloader-erase step and does not
            # use a password. Reject these flags instead of silently ignoring
            # them: a user must not believe they are in the safer mode when
            # the flag has no effect.
            if args.no_erase_bootloader:
                parser.error(
                    '--no-erase-bootloader is only supported for OPTIMUS '
                    'images; this image uses the ADNL protocol, which has no '
                    'separate bootloader-erase step. Remove the flag.')
            if args.password:
                parser.error(
                    '--password is only supported for OPTIMUS images; '
                    'this image uses the ADNL protocol.')
            do_adnl_burn(args.reset, args.wipe.value, aml_img)
        else:
            do_optimus_burn(args, aml_img)
    except (RuntimeError, TimeoutError) as exc:
        logging.error('%s', exc)
        return 2

    return 0


if __name__ == '__main__':
    sys.exit(main())
