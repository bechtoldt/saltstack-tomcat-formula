#!py
# -*- coding: utf-8 -*-
# vim: ts=4 sw=4 et

__formname__ = 'tomcat'


def run():
    config = {}
    datamap = __salt__['formhelper.get_defaults'](__formname__, __env__, ['yaml'])['yaml']

    _gen_state = __salt__['formhelper.generate_state']
    instance_default_user = datamap['instance_defaults'].get('user', 'tomcat')
    instance_default_group = datamap['instance_defaults'].get('group', 'tomcat')

    # SLS includes/ excludes
    config['include'] = datamap.get('sls_include', [])
    config['extend'] = datamap.get('sls_extend', {})

    # State tomcat base directory
    attrs = [
                {'name': datamap['instance_defaults'].get('basedir')},
                {'mode': 755},
                {'user': instance_default_user},
                {'group': instance_default_group},
                {'makedirs': True},
                ]

    config['tomcat_base_dir'] = _gen_state('file', 'directory', attrs)

    for i_id, instance in datamap.get('instances', {}).iteritems():
        instance_dir = instance.get('basedir', '{0}/{1}'.format(datamap['instance_defaults'].get('basedir'), i_id))

        # State instance directory
        attrs = [
            {'name': instance_dir},
            {'source': instance.get('source')},
            {'keep': instance.get('archive_cache', True)},
            {'archive_format': instance.get('archive_format', 'tar')},
            ]

        if 'source_hash' in instance:
            attrs.append({'source_hash': instance.get('source_hash')})

        config['tomcat_{0}_archive'.format(i_id)] = _gen_state('archive', 'extracted', attrs)

        # State tomcat archive link
        archive_dir = instance.get('archive_dir', 'apache-tomcat-{0}'.format(instance.get('version')))
        attrs = [
            {'name': '{0}/{1}'.format(instance_dir, instance.get('version'))},
            {'target': '{0}/{1}'.format(instance_dir, archive_dir)},
            {'user': instance_default_user},
            {'group': instance_default_group},
            ]

        config['tomcat_{0}_archive_link'.format(i_id)] = _gen_state('file', 'symlink', attrs)

        for w_id, webapp in instance.get('webapps', {}).iteritems():
            if not webapp.get('manage', False):
                continue

            webapps_root = webapp.get(instance_default_user, '{0}/{1}/webapps'.format(instance_dir,
                                                                                      instance.get('version')))
            webapp_root = webapp.get(instance_default_group, '{0}/{1}'.format(webapps_root, webapp.get('alias', w_id)))

            if webapp.get('ensure', 'present') == 'absent':
                # State webapp dir
                attrs = [
                    {'name': webapp_root},
                    {'user': instance_default_user},
                    {'group': instance_default_group},
                    {'mode': 750},
                    ]

                config['tomcat_{0}_webapp_{1}_dir'.format(i_id, w_id)] = _gen_state('file', webapp.get('ensure'), attrs)

            if 'war' in webapp:
                # State webapp war file
                war_file = '{0}/{1}'.format(webapps_root, webapp['war'].get('name', webapp.get('alias',
                                                                                               '{0}.war'.format(w_id))))
                attrs = [
                    {'name': war_file},
                    {'source': webapp['war'].get('source')},
                    {'user': instance_default_user},
                    {'group': instance_default_group},
                    {'mode': 644},
                    ]

                if 'source_hash' in webapp['war']:
                    attrs.append({'source_hash': webapp['war'].get('source_hash')})

                config['tomcat_{0}_webapp_{1}_war'.format(i_id, w_id)] = _gen_state('file',
                                                                                    webapp.get('ensure', 'managed'),
                                                                                    attrs)

            # State tomcat instance dir perms
            attrs = [
                {'name': instance_dir},
                {'user': instance_default_user},
                {'group': instance_default_group},
                {'mode': 755},
                {'recurse': ['user', 'group']},
                ]

            config['tomcat_{0}_dirperms'.format(i_id)] = _gen_state('file', 'directory', attrs)
    return config
