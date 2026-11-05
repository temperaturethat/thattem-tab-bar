# ERT regression tests

Five independently loadable suites cover lifecycle, common items, mouse actions,
workspace controls and monitor sampling. `thattem-tab-bar-test-helper.el` provides
shared fixtures. Loading a suite only defines tests; it does not run or exit Emacs.
There is no shell runner, executable batch wrapper or CI scaffold.

## Dependencies

Use Emacs with real nerd-icons and a loadable `libthattem_emacs_library.so`.
The native module is required by the production package even for the default
style. Tests do not silently replace it or skip missing dependencies.

If the module is installed beside `thattem-tab-bar.el`, the package finds it
normally. Otherwise pass its absolute filename **before loading any suite**:

```sh
--eval '(setq thattem-tab-bar-thattem-library-path "/absolute/path/libthattem_emacs_library.so")'
```

That same option is needed during byte compilation because production code
loads the module at compile time too. Its runtime shared-library dependencies
must remain available. No test invokes the real workspace switch or samples a
live desktop; native query/action boundaries use controlled inputs. Native C
correctness and desktop D-Bus integration are outside this suite's claims.

For Nix, enter an environment with nerd-icons:

```sh
nix-shell -p '(emacsPackagesFor emacs-nox).emacsWithPackages (ep: [ ep.nerd-icons ])'
```

For separate checkouts, add `-L /path/to/nerd-icons.el` and, for versions needing
it, `-L /path/to/nerd-icons.el/data`. `-Q` does not activate the user's package
installation. Verification used Emacs 31.1, nerd-icons revision
`87ae84981ddeb4446586ba65cb30cec6e6ccfdb0`, and the real native module built from
`thattem-emacs-library` revision `4e85cc2c014f9e580fe5663b6a7f770cf2e225a0`.
This is not an older-version compatibility claim.

## Direct commands

From the project root, with dependencies configured as above:

```sh
emacs -Q --batch -L . -L test \
  --eval '(progn
    (dolist (file (directory-files "test" t "-tests[.]el$"))
      (load file nil t))
    (ert-run-tests-batch-and-exit "^thattem-tab-bar-test--"))'
```

Run just one suite:

```sh
emacs -Q --batch -L . -L test \
  -l test/thattem-tab-bar-actions-tests.el \
  -f ert-run-tests-batch-and-exit
```

For selected cases, replace `-f ert-run-tests-batch-and-exit` with e.g.
`--eval '(ert-run-tests-batch-and-exit "thattem-tab-bar-test--.*workspace")'`.
Interactively, add the project and `test/` directories to `load-path`, configure
the module filename if necessary, load the suites and use `M-x ert`.

## Source and compiled checks

Test source in a copy without `.elc` files. Compile only in a scratch copy of
the five package libraries and `test/`, keeping the native module available:

```sh
emacs -Q --batch -L . -L test \
  --eval '(setq byte-compile-error-on-warn t)' \
  -f batch-byte-compile thattem-tab-bar*.el test/*.el
```

Run the combined command in a fresh process, changing `"-tests[.]el$"` to
`"-tests[.]elc$"` to load compiled suites explicitly. Inspect `load-history` to
check that all package libraries, the helper and suites loaded from that scratch
directory as `.elc` files rather than falling back to source/an installed copy.
ERT exits nonzero on unexpected failure; strict compilation fails on warnings.

The load-side-effect test starts a fresh Emacs subprocess with the same load
paths and module option. It checks first `require`, not a misleading second
`require` after the package is already initialized.

## Contracts and boundaries

- **Lifecycle:** default/modern style activation, nil and non-nil originals,
  repeated toggles, new baselines, timer identity/cancellation, advice identity,
  conventional minor-mode map, global-map preservation and error cleanup.
- **Items:** history/add-tab commands, name length boundary, Unicode/percent
  names, optional hints, close-button policies, killed buffers, saved inactive
  tab state, tab order, empty providers, alignment recursion guards and faces.
- **Actions:** workspace ID zero, current-workspace no-op, nil-string fallback,
  exact interval edges, absent/error controls, wheel variants, plain release,
  suppression after a wheel gesture and preservation of duplicate events.
- **Workspaces:** wraparound, a single workspace, failed queries, full target
  IDs beyond one icon digit, absent-widget range cleanup and prefix measurement.
- **Monitoring:** full sample windows, bounded histories, frequency one, idle
  data, directional rates and the exact warning threshold.

The visible `!` indicator intentionally absorbs wheel events. Character-first
replay followed by the original middle-button-down intentionally re-arms the
handler. Tests preserve these clarified behaviors rather than asserting a
chronological input replay policy.

Lifecycle fixtures use real timers and real advice but intercept core
`tab-bar-mode` activation to avoid reconfiguring interactive frames. Core mode
ownership, overlapping whole-format replacement by unrelated modes, live
style-customization policy and startup averaging policy are not invented here.

Mouse tests explicitly invoke callbacks with constructed events. The replay
model checks callback/queue behavior, not command-loop delivery. Geometry
inputs are controlled where necessary. Exact icon glyphs, colors, clipping,
pixel alignment, physical mouse delivery, multiple graphical frames and a live
GNOME workspace service still require integration/display tests.
