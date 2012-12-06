Nines::App.config = {
  contacts: {
    'admin' => { email: 'admin@example.com' },
  },
  check_groups: [
    { name: 'Google',
      parameters: { type: :http },
      notify: [ { contact: 'admin' } ],
      checks: [ 'www.google.com' ]
    }
  ]
}
