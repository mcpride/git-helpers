# Partial git submodules

The powershell script `gitmodule-sparse-checkout.ps1` includes commands which combine git submodule handling with git partial checkout ([git sparse-checkout](https://git-scm.com/docs/git-sparse-checkout)):

* `./gitmodule-sparse-checkout.ps1 backup`:
  * Backups configured sparse-checkout filters of git submodules into .gitmodules file (see property "sparse-checkout").
* `./gitmodule-sparse-checkout.ps1 restore`:
  * Restores / updates git submodules based on the information in the .gitmodules file with "sparse-checkout" support.

## Workflows

### Add a submodule

* Example 1:

```shell
>git submodule add -- "../../../apps/app1/app1-service1.git" "external/app1-service1"
```

* Example 2 (named):

```shell
>git submodule add --name "app1-service1" -- "../../../apps/app1/app1-service1.git" "external/app1-service1"
```

* Example 3 (target a specific branch):

```shell
>git submodule add --branch master -- "../../../apps/app1/app1-service1.git" "external/app1-service1"
```

| _*TIP!*_ | Use relative URL's for the repository! |
|----------|----------------------------------------|


### Configure a partial submodule checkout

#### Initialization for partial checkout

* Example 4:

```shell
>git -C "external/app1-service1" sparse-checkout init
```

| _*HINT!*_ | The `external/app1-service1` parameter in this example targets the submodule's PATH - not the name! |
|-----------|-----------------------------------------------------------------------------------------------------|

#### Add directory filters

* Examples 5:

```shell
>git -C "external/app1-service1" sparse-checkout add doc/adr
>git -C "external/app1-service1" sparse-checkout add scripts
```

#### List directory filters

* Example 6:

```shell
>git -C "external/app1-service1" sparse-checkout list
doc/adr
scripts
```

#### Backup submodule's directory filters to .gitmodules

* Git config example 7 (for a single submodule):

```shell
>git config -f .gitmodules submodule.external/app1-service1.sparse-checkout "doc/adr scripts"
```

| _*HINT!*_ | The string *submodule.`external/app1-service1`.sparse-checkout* in this example targets the submodule's NAME - not the path! |
|-----------|------------------------------------------------------------------------------------------------------------------------------|

... or ...

* Powershell script example 8 (for all submodules in a git repository):

```shell
>powershell -ExecutionPolicy Bypass -NoLogo -Command "./gitmodule-sparse-checkout.ps1"
```

### Restore (partial) submodules after local clone

#### Clone a git repository (which contains submodules)

* Example 9:

```shell
>git clone "git@scm-01.karlstorz.com:sis/documentation/gpdp/system-engineering.git"
```

#### Restore git submodules with partial-checkout support

* Powershell script example 10:

```shell
>powershell -ExecutionPolicy Bypass -NoLogo -Command "./gitmodule-sparse-checkout.ps1"
```

### Other git commands

#### Update a submodule

* Update a submodule remotly with rebase example 11:

```shell
>git submodule update --force --no-fetch --rebase --remote -- "external/app1-service1"
```

## Restrictions

* Don't use spaces ` ` and dots `.` in your submodule names! Instead use the `--name <valid-submodule-name>` parameter when adding submodules, and choose a valid name which can also act as a directory name without spaces ` ` and dots `.` (see Example 2).
* Don't use single quotes `'` inside directory filters, e.g. `users/Charly's Tante/documents`! There is currently no fix!
* Use slashes `/` instead of backslashes `\` for platform compatibility!

### Credits

The behavior of the scripts is based on Nathan Reed's python script, located here:
 
* [git-partial-submodule.py](https://github.com/Reedbeta/git-partial-submodule/blob/main/git-partial-submodule.py)


## License

The source code of this repository is under MIT license. See the [LICENSE](../LICENSE) file for details. 