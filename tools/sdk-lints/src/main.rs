/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0.
 */

use crate::changelog::ChangelogNext;
use crate::copyright::CopyrightHeader;
use crate::lint::{Check, Fix, Lint, LintError, Mode};
use crate::lint_cargo_toml::{CrateAuthor, CrateLicense, DocsRs};
use crate::readmes::{ReadmesExist, ReadmesHaveFooters};
use crate::todos::TodosHaveContext;
use anyhow::{bail, Context, Result};
use lazy_static::lazy_static;
use std::env::set_current_dir;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::{fs, io};
use structopt::StructOpt;

mod anchor;
mod changelog;
mod copyright;
mod lint;
mod lint_cargo_toml;
mod readmes;
mod todos;

fn load_repo_root() -> Result<PathBuf> {
    let output = Command::new("git")
        .arg("rev-parse")
        .arg("--show-toplevel")
        .output()
        .with_context(|| "couldn't load repo root")?;
    Ok(PathBuf::from(String::from_utf8(output.stdout)?.trim()))
}

#[derive(Debug, StructOpt)]
enum Args {
    Check {
        #[structopt(long)]
        all: bool,
        #[structopt(long)]
        readme: bool,
        #[structopt(long)]
        cargo_toml: bool,
        #[structopt(long)]
        docsrs_metadata: bool,
        #[structopt(long)]
        changelog: bool,
        #[structopt(long)]
        license: bool,
        #[structopt(long)]
        todos: bool,
    },
    Fix {
        #[structopt(long)]
        readme: bool,
        #[structopt(long)]
        docsrs_metadata: bool,
        #[structopt(long)]
        all: bool,
        #[structopt(long)]
        dry_run: Option<bool>,
    },
    UpdateChangelog {
        #[structopt(long)]
        smithy_version: String,
        #[structopt(long)]
        sdk_version: String,
        #[structopt(long)]
        date: String,
    },
}

fn load_vcs_files() -> Result<Vec<PathBuf>> {
    let tracked_files = Command::new("git")
        .arg("ls-tree")
        .arg("-r")
        .arg("HEAD")
        .arg("--name-only")
        .current_dir(load_repo_root()?)
        .output()
        .context("couldn't load VCS tracked files")?;
    let mut output = String::from_utf8(tracked_files.stdout)?;
    let changed_files = Command::new("git")
        .arg("diff")
        .arg("--name-only")
        .output()?;
    output.push_str(std::str::from_utf8(changed_files.stdout.as_slice())?);
    let files = output
        .lines()
        .map(|line| PathBuf::from(line.trim().to_string()));
    Ok(files.collect())
}

lazy_static! {
    static ref REPO_ROOT: PathBuf = load_repo_root().unwrap();
    static ref VCS_FILES: Vec<PathBuf> = load_vcs_files().unwrap();
}

fn repo_root() -> &'static Path {
    REPO_ROOT.as_path()
}

fn ok<T>(errors: Vec<T>) -> anyhow::Result<()> {
    if errors.is_empty() {
        Ok(())
    } else {
        bail!("Lint errors occurred");
    }
}

fn main() -> Result<()> {
    set_current_dir(repo_root())?;
    let opt = Args::from_args();
    match opt {
        Args::Check {
            all,
            readme,
            cargo_toml,
            docsrs_metadata,
            changelog,
            license,
            todos,
        } => {
            let mut errs = vec![];
            if readme || all {
                errs.extend(ReadmesExist.check_all()?);
                errs.extend(ReadmesHaveFooters.check_all()?);
            }
            if cargo_toml || all {
                errs.extend(CrateAuthor.check_all()?);
                errs.extend(CrateLicense.check_all()?);
            }

            if docsrs_metadata || all {
                errs.extend(DocsRs.check_all()?);
            }

            if license || all {
                errs.extend(CopyrightHeader.check_all()?);
            }
            if changelog || all {
                errs.extend(ChangelogNext.check_all()?);
            }
            if todos || all {
                errs.extend(TodosHaveContext.check_all()?);
            }
            ok(errs)?
        }
        Args::Fix {
            readme,
            docsrs_metadata,
            all,
            dry_run,
        } => {
            let dry_run = match dry_run.unwrap_or(false) {
                true => Mode::DryRun,
                false => Mode::NoDryRun,
            };
            if readme || all {
                ok(ReadmesHaveFooters.fix_all(dry_run)?)?;
            }
            if docsrs_metadata || all {
                ok(DocsRs.fix_all(dry_run)?)?;
            }
        }
        Args::UpdateChangelog {
            smithy_version,
            sdk_version,
            date,
        } => changelog::update_changelogs(
            repo_root().join("CHANGELOG.next.toml"),
            repo_root().join("CHANGELOG.md"),
            repo_root().join("aws/SDK_CHANGELOG.md"),
            &smithy_version,
            &sdk_version,
            &date,
        )?,
    }
    Ok(())
}

fn ls(path: impl AsRef<Path>) -> Result<impl Iterator<Item = PathBuf>> {
    Ok(fs::read_dir(path.as_ref())
        .with_context(|| format!("failed to ls: {:?}", path.as_ref()))?
        .map(|res| res.map(|e| e.path()))
        .collect::<Result<Vec<_>, io::Error>>()?
        .into_iter())
}

fn smithy_rs_crates() -> Result<impl Iterator<Item = PathBuf>> {
    let smithy_crate_root = repo_root().join("rust-runtime");
    Ok(ls(smithy_crate_root)?.filter(|path| is_crate(path.as_path())))
}

fn is_crate(path: &Path) -> bool {
    path.is_dir() && path.join("Cargo.toml").exists()
}

fn aws_runtime_crates() -> Result<impl Iterator<Item = PathBuf>> {
    let aws_crate_root = repo_root().join("aws").join("rust-runtime");
    Ok(ls(aws_crate_root)?.filter(|path| is_crate(path.as_path())))
}

fn all_runtime_crates() -> Result<impl Iterator<Item = PathBuf>> {
    Ok(aws_runtime_crates()?.chain(smithy_rs_crates()?))
}

fn all_cargo_tomls() -> Result<impl Iterator<Item = PathBuf>> {
    Ok(all_runtime_crates()?.map(|pkg| pkg.join("Cargo.toml")))
}
