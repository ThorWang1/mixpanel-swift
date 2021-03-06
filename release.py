
import argparse
import subprocess


parser = argparse.ArgumentParser(description='Release Mixpanel Swift SDK')
parser.add_argument('--old', help='version for the release', action="store")
parser.add_argument('--new', help='version for the release', action="store")
args = parser.parse_args()

def bump_version():
    replace_version('Mixpanel-swift.podspec', args.old, args.new)
    replace_version('Mixpanel/Info.plist', args.old, args.new)
    replace_version('generate_docs.sh', args.old, args.new)
    subprocess.call('git add Mixpanel-swift.podspec', shell=True)
    subprocess.call('git add Mixpanel/Info.plist', shell=True)
    subprocess.call('git add generate_docs.sh', shell=True)
    subprocess.call('git commit -m "Version {}"'.format(args.new), shell=True)
    subprocess.call('git push', shell=True)

def replace_version(file_name, old_version, new_version):
    with open(file_name) as f:
        file_str = f.read()
        assert(old_version in file_str)
        file_str = file_str.replace(old_version, new_version)

    with open(file_name, "w") as f:
        f.write(file_str)

def generate_docs():
    subprocess.call('./generate_docs.sh', shell=True)
    subprocess.call('git add docs', shell=True)
    subprocess.call('git commit -m "Update docs"', shell=True)
    subprocess.call('git push', shell=True)

def add_tag():
    subprocess.call('git tag -a v{} -m "version {}"'.format(args.new, args.new), shell=True)
    subprocess.call('git push origin --tags', shell=True)

def pushPod():
    subprocess.call('pod trunk push Mixpanel-swift.podspec --allow-warnings', shell=True)

def build_Carthage():
    subprocess.call('carthage build --no-skip-current', shell=True)
    subprocess.call('carthage archive Mixpanel', shell=True)

def main():
    bump_version()
    generate_docs()
    add_tag()
    pushPod()
    build_Carthage()
    print("Congratulations, done!")

if __name__ == '__main__':
    main()